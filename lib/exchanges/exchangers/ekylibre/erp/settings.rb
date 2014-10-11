# Create or updates entities
Exchanges.add_importer :ekylibre_erp_settings do |file, w|

  manifest = YAML.load_file(file).deep_symbolize_keys

  # TODO: Find a cleaner way to manage those following methods
  def manifest.can_load?(key)
    !self[key].is_a?(FalseClass)
  end

  def manifest.can_load_default?(key)
    can_load?(key) and !self[key].is_a?(Hash)
  end

  def manifest.create_records(records, *args)
    options = args.extract_options!
    main_column = args.shift || :name
    model = records.to_s.classify.constantize
    if data = self[records]
      @records ||= {}.with_indifferent_access
      @records[records] ||= {}.with_indifferent_access
      unless data.is_a?(Hash)
        raise "Cannot load #{records}: Hash expected, got #{records.class.name} (#{records.inspect})"
      end
      for identifier, attributes in data
        attributes = attributes.with_indifferent_access
        attributes[main_column] ||= identifier.to_s
        for reflection in model.reflections.values
          if attributes[reflection.name] and not attributes[reflection.name].class < ActiveRecord::Base
            attributes[reflection.name] = get_record(reflection.class_name.tableize, attributes[reflection.name].to_s)
          end
        end
        @records[records][identifier.to_s] = model.create!(attributes)
      end
    end
  end

  # Returns the record corresponding to the identifier
  def manifest.get_record(records, identifier)
    @records ||= {}.with_indifferent_access
    if @records[records]
      return @records[records][identifier]
    end
    return nil
  end

  manifest[:company]      ||= {}
  manifest[:net_services] ||= {}
  manifest[:identifiers]  ||= {}
  manifest[:language]     ||= ::I18n.default_locale

  # Manual count of check_points
  # $ grep -rin check_point lib/exchanges/exchangers/ekylibre/erp/settings.rb | wc -l
  w.count = 21

  # Global preferences
  language = I18n.locale = manifest[:language]
  currency = manifest[:currency] || 'EUR'
  country  = manifest[:country]  || 'fr'
  Preference.get(:language).set!(language)
  Preference.get(:currency).set!(currency)
  Preference.get(:country).set!(country)
  if srs = manifest[:map_measure_srs]
    Preference.get(:map_measure_srs).set!(srs)
  elsif srid = manifest[:map_measure_srid]
    Preference.get(:map_measure_srs).set!(Nomen::SpatialReferenceSystems.find_by(srid: srid.to_i).name)
  end

  w.check_point

  # Sequences
  if manifest.can_load?(:sequences)
    Sequence.load_defaults
  end
  w.check_point

  # Company entity
  # f = nil
  # for format in %w(jpg jpeg png)
  #   if company_picture = first_run.path("alamano", "logo.#{format}") and company_picture.exist?
  #     f = File.open(company_picture)
  #     break
  #   end
  # end
  attributes = {language: language, currency: currency, nature: "company", last_name: "Ekylibre"}.merge(manifest[:company].select{|k,v| ![:addresses].include?(k) }).merge(of_company: true)
  company = LegalEntity.create!(attributes)
  # f.close if f
  if manifest[:company][:addresses].is_a?(Hash)
    for address, value in manifest[:company][:addresses]
      if value.is_a?(Hash)
        value[:canal] ||= address
        for index in (1..6).to_a
          value["mail_line_#{index}"] = value.delete("line_#{index}".to_sym)
        end
        company.addresses.create!(value)
      else
        company.addresses.create!(canal: address, coordinate: value)
      end
    end
  end
  w.check_point

  # Teams
  if manifest.can_load_default?(:teams)
    manifest[:teams] = {default: {name: Establishment.tc('default')}}
  end
  manifest.create_records(:teams)
  w.check_point

  # Establishment
  if manifest.can_load_default?(:establishments)
    manifest[:establishments] = {default: {name: Establishment.tc('default')}}
  end
  manifest.create_records(:establishments)
  w.check_point

  # Roles
  if manifest.can_load_default?(:roles)
    manifest[:roles] = {
      default: {name: Role.tc('default.public')},
      administrator: {name: Role.tc('default.administrator'), rights: Ekylibre::Access.actions}
    }
  end
  manifest.create_records(:roles)
  w.check_point

  # Users
  if manifest.can_load_default?(:users)
    manifest[:users] = {"admin@ekylibre.org" => {first_name: "Admin", last_name: "EKYLIBRE"}}
  end
  for email, attributes in manifest[:users]
    attributes[:email] = email.to_s
    attributes[:administrator] = true unless attributes.has_key?(:administrator)
    attributes[:language] ||= language
    for ref in [:role, :team, :establishment]
      attributes[ref] ||= :default
      attributes[ref] = manifest.get_record(ref.to_s.pluralize, attributes[ref])
    end
    unless attributes[:password]
      if Rails.env.development?
        attributes[:password] = "12345678"
      else
        attributes[:password] = User.give_password(8, :normal)
        puts "New password for account #{attributes[:email]}: #{attributes[:password]}"
      end
    end
    attributes[:password_confirmation] = attributes[:password]
    User.create!(attributes)
  end
  w.check_point

  # Catalogs
  manifest.create_records(:catalogs, :code)
  w.check_point

  # Load chart of account
  if chart = manifest[:chart_of_accounts] || manifest[:chart_of_account]
    Account.chart = chart
    Account.load
  end
  w.check_point

  # Load accounts
  manifest.create_records(:accounts)
  w.check_point

  # Load financial_years
  manifest.create_records(:financial_years, :code)
  w.check_point

  # Load taxes from nomenclatures
  if manifest.can_load?(:taxes)
    Tax.import_all_from_nomenclature(country.to_sym)
  end
  w.check_point

  # Load all the document templates
  if manifest.can_load?(:document_templates)
    DocumentTemplate.load_defaults
  end
  w.check_point

  # Loads journals
  if manifest.can_load_default?(:journals)
    manifest[:journals] = Journal.nature.values.inject({}) do |hash, nature|
      hash[nature] = {name: "enumerize.journal.nature.#{nature}".t, nature: nature.to_s, currency: currency, closed_on: Date.new(1899, 12, 31).end_of_month}
      hash
    end
  end
  manifest.create_records(:journals, :code)
  w.check_point

  # Load cashes
  manifest.create_records(:cashes)
  w.check_point

  # Load incoming payment modes
  if manifest.can_load_default?(:incoming_payment_modes)
    manifest[:incoming_payment_modes] = %w(cash check transfer).inject({}) do |hash, nature|
      hash[nature] = {name: IncomingPaymentMode.tc("default.#{nature}.name"), with_accounting: true, cash: Cash.find_by(nature: Cash.nature.values.include?(nature) ? nature : :bank_account), with_deposit: (nature == "check" ? true : false)}
      if hash[nature][:with_deposit] and journal = Journal.find_by(nature: "bank")
        hash[nature][:depositables_journal] = journal
        hash[nature][:depositables_account] = Account.find_or_create_in_chart(:pending_deposit_payments)
      else
        hash[nature][:with_deposit] = false
      end
      hash
    end
  end
  manifest.create_records(:incoming_payment_modes)
  w.check_point

  # Load outgoing payment modes
  if manifest.can_load_default?(:outgoing_payment_modes)
    manifest[:outgoing_payment_modes] = %w(cash check transfer).inject({}) do |hash, nature|
      hash[nature] = {name: OutgoingPaymentMode.tc("default.#{nature}.name"), with_accounting: true, cash: Cash.find_by(nature: Cash.nature.values.include?(nature) ? nature : :bank_account)}
      hash
    end
  end
  manifest.create_records(:outgoing_payment_modes)
  w.check_point

  # Load sale natures
  if manifest.can_load_default?(:sale_natures)
    nature = :sales
    journal = Journal.find_by(nature: nature, currency: currency) || Journal.create!(name: "enumerize.journal.nature.#{nature}".t, nature: nature.to_s, currency: currency, closed_on: Date.new(1899, 12, 31).end_of_month)
    manifest[:sale_natures] = {default: {name: SaleNature.tc('default.name'), active: true, expiration_delay: "30 day", payment_delay: "30 day", downpayment: false, downpayment_minimum: 300, downpayment_percentage: 30, currency: currency, with_accounting: true, journal: journal, catalog: Catalog.of_usage(:sale).first}}
  end
  manifest.create_records(:sale_natures)
  w.check_point

  # Load purchase natures
  if manifest.can_load_default?(:purchase_natures)
    nature = :purchases
    journal = Journal.find_by(nature: nature, currency: currency) || Journal.create!(name: "enumerize.journal.nature.#{nature}".t, nature: nature.to_s, currency: currency, closed_on: Date.new(1899, 12, 31).end_of_month)
    manifest[:purchase_natures] = {default: {name: PurchaseNature.tc("default.name"), active: true, currency: currency, with_accounting: true, journal: journal}}
  end
  manifest.create_records(:purchase_natures)
  w.check_point

  # Load net services
  for name, identifiers in manifest[:net_services]
    service = NetService.create!(reference_name: name)
    for nature, value in identifiers
      service.identifiers.create!(nature: nature, value: value)
    end
  end
  w.check_point

  # Load identifiers
  for nature, value in manifest[:identifiers]
    Identifier.create!(nature: nature, value: value)
  end
  w.check_point

end

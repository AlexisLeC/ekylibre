
Exchanges.add_importer :bordeaux_sciences_agro_istea_general_ledger do |file, w|

  rows = CSV.read(file, encoding: "CP1252", col_sep: ";")
  w.count = rows.size
    
  rows.each do |row|
    r = OpenStruct.new(:account => Account.get(row[0]),
                       :journal => Journal.find_by(code: row[1]) || Journal.create!(name: "Journal #{row[1]}", code: row[1], currency: "EUR"),
                       :page_number => row[2], # What's that ?
                       :printed_on => Date.civil(*row[3].split(/\-/).map(&:to_i)),
                       :entry_number => row[4].to_s.strip.mb_chars.upcase.to_s.gsub(/[^A-Z0-9]/, ''),
                       :entity_name => row[5],
                       :entry_name => row[6],
                       :debit => row[7].to_d,
                       :credit => row[8].to_d,
                       :vat => row[9],
                       :comment => row[10],
                       :letter => row[11],
                       :what_on => row[12])


    fy = FinancialYear.at(r.printed_on)
    unless entry = JournalEntry.find_by(journal_id: r.journal.id, number: r.entry_number)
      number = r.entry_number
      number = r.journal.code + rand(10000000000).to_s(36) if number.blank?
      entry = r.journal.entries.create!(:printed_at => r.printed_on.to_datetime, :number => number.mb_chars.upcase)
    end
    column = (r.debit.zero? ? :credit : :debit)
    entry.send("add_#{column}", r.entry_name, r.account, r.send(column))

    w.check_point
  end

end

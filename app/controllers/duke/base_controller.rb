module Duke
  class BaseController < ::ApiController
    wrap_parameters false
    respond_to :json
    
  end
end

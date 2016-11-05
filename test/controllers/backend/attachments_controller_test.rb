require 'test_helper'
module Backend
  class AttachmentsControllerTest < ActionController::TestCase
    test_restfully_all_actions create: { params: { subject_type: 'Entity', subject_id: 2 } }, except: :destroy

    test 'destroy action' do
      attachment = attachments(:attachments_002)
      delete :destroy, params: { id: attachment.id, locale: @locale }
      assert_response :ok
      assert_equal 'deleted', JSON.parse(response.body)['attachment']
    end
  end
end

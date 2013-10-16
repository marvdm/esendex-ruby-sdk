require 'nokogiri'

module Esendex
  class Account
    attr_accessor :reference
    
    def initialize(account_reference = Esendex.account_reference)
      @reference = account_reference
    end
    
    def api_connection
      @api_connection ||= ApiConnection.new
    end

    def messages_remaining
      response = api_connection.get "/v1.0/accounts"
      doc = Nokogiri::XML(response.body)
	  node = doc.at_xpath("//api:account[api:reference='#{@reference}']/api:messagesremaining", 'api' => Esendex::API_NAMESPACE)
	  raise AccountReferenceError.new() if node.nil?
	  node.content.to_i
    end

    def send_message(args={})
      raise ArgumentError.new(":to required") unless args[:to]
      raise ArgumentError.new(":body required") unless args[:body]

      send_messages([Message.new(args[:to], args[:body], args[:from])])
    end

    def send_message_and_get_id(args={})
      raise ArgumentError.new(":to required") unless args[:to]
      raise ArgumentError.new(":body required") unless args[:body]

      message = [Message.new(args[:to], args[:body], args[:from])]
      batch_submission = MessageBatchSubmission.new(@reference, message)

      response = api_connection.post "/v1.0/messagedispatcher", batch_submission.to_s
      doc = Nokogiri::XML(response.body)

      doc.at_xpath('//api:messageheaders', 'api' => Esendex::API_NAMESPACE).children.first[:id]
    end

    def send_messages(messages)
      batch_submission = MessageBatchSubmission.new(@reference, messages)
      response = api_connection.post "/v1.0/messagedispatcher", batch_submission.to_s
      doc = Nokogiri::XML(response.body)
      doc.at_xpath('//api:messageheaders', 'api' => Esendex::API_NAMESPACE)['batchid']
    end


    def retrieve_message(message_id)
      response = api_connection.get "/v1.0/messageheaders/#{message_id}"

      begin
        doc = Nokogiri::XML(response.body)
        { reference: doc.at('reference').try(:text),
          sentat: doc.at('sentat').try(:text),
          laststatusat: doc.at('laststatusat').try(:text),
          submittedat: doc.at('submittedat').try(:text),
          type: doc.at('type').try(:text),
          status: doc.at('status').try(:text),
          to: doc.at('to phonenumber').try(:text),
          from: doc.at('from phonenumber').try(:text),
          direction: doc.at('direction').try(:text),
          parts: doc.at('parts').try(:text) }
      rescue Esendex::ApiError => e
        e.to_s.match(/Response message = (.+)$/)[1]
      rescue StandardError => e
        'Standard error'
      end
    end


    def retrieve_messages
      response = api_connection.get "/v1.0/messageheaders"

      begin
        doc = Nokogiri::XML(response.body)
        message_headers = doc.at('messageheaders').css('messageheader')

        messages = message_headers.map do |m|
          { id:           m.attr('id'),
            reference:    m.at('reference').try(:text),
            status:       m.at('status').try(:text),
            sentat:       m.at('sentat').try(:text),
            laststatusat: m.at('laststatusat').try(:text),
            submittedat:  m.at('submittedat').try(:text),
            type:         m.at('type').try(:text),
            to:           m.at('to phonenumber').try(:text),
            from:         m.at('from phonenumber').try(:text),
            direction:    m.at('direction').try(:text),
            parts:        m.at('parts').try(:text) }
        end
      rescue Esendex::ApiError => e
        e.to_s
      rescue StandardError => e
        e.to_s
      end
    end

  end
end

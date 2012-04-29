class TwilioController < ApplicationController
  def sms
    if params[:AccountSid] != ENV["TWILIO_KEY"]
      logger.error "Invalid Twilio account access: #{$params}"
      render :nothing => true and return
    end

    @from_phone = params[:From].normalize_phone!
    @customer = Person.find_by_phone(params[:From])
    if nil == @customer
      sms_response "BACE: We don't recognize this phone number, please add it to your profile" and return
    end

    text = params[:Body].downcase.split
    action = text.shift
    case action
    when /^b/
      ### Balance
      sms_response "BACE: Your balance is #{@customer.account.balance}" and return
    when /^p/
      ### Payments
      if (text.length < 2)
        sms_response "BACE: We didn't get enough information. To pay someone text 'pay 555-555-5555 ##'" and return
      elsif /(^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$)/ =~ text[0]
        @worker = Person.find_by_email(text[0])
      else
        @worker = Person.find_by_phone(text[0].normalize_phone!)
      end

      if nil == @worker
        sms_response "BACE: Bad or unknown email address or phone number when trying to pay. You entered: '" + text[0] + "'" and return
      end

      if /^\d+$/ !~ text[1]
        sms_response "BACE: Please enter a valid number of hours to pay. You entered: '" + text[1] + "'" and return
      end
      amount = text[1].to_i

      memo = text[2, text.length]
      # ignore 'hours', 'hour', 'for' and 'to' at the beginning of a payment memo
      while ['hours', 'hour', 'for', 'to'].include?(memo[0])
        memo.shift
      end
      memo = memo.join(" ")

      begin
        req = Req.new(:name => memo.blank? ? 'miscellaneous' : memo, :estimated_hours => amount, :due_date => Time.now, :active => false);
        req.person = @customer
        req.save!
        @transact = Exchange.new(:amount => amount)
        @transact.metadata = req
        @transact.customer = @customer
        @transact.worker = @worker
        @transact.save!
      rescue StandardError => msg
        logger.error "Error processing payment: " + msg
        sms_response "BACE: Something went wrong sending your payment of #{text[1]} hours to #{text[0]}. Please try again" and return
      end

      ### TODO: what language to use
      sms_response "BACE: You paid #{text[1]} hours to #{text[0]}"
    when /^r/
      ### Request
      query = text.join(" ")
      if /(\d)+\s+hours?/ =~ query
        hours = $~[1]
        query = query.gsub(/(\d)+\s+hours?(\s+of)?/, "")
      end

      req = Req.new(:estimated_hours => hours, :name => query, :due_date => 7.days.from_now)
      req.person = @customer ## XXX: no idea why i can't just specify person_id above but then it has a nil person object, shouldn't it load that from the db?
      begin
        req.save!
      rescue StandardError => msg
        logger.error "Error posting request: " + msg + " \n " + msg.backtrace.join("\n")
        sms_response "BACE: Something went wrong posting your request. Please try again" and return
      end
      sms_response "BACE: Your request has been posted"
    else
      sms_response "BACE: We didn't understand #{action}. Available options are 'pay', 'balance', 'search', 'request'"
    end
  end

  private
    def sms_response(text)
      Twilio.connect(ENV['TWILIO_KEY'], ENV["TWILIO_SECRET"])
      Twilio::Sms.message(ENV["TWILIO_NUMBER"], @from_phone, text)
      render :nothing => true
    end
end
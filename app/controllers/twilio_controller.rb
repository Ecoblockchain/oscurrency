class TwilioController < ApplicationController
  def sms
    if params[:AccountSid] != ENV["TWILIO_KEY"]
      logger.error "Invalid Twilio account access: #{$params}"
      exit
    end

    @from_phone = params[:From].normalize_phone!
    logger.debug(@from_phone)
    @customer = Person.find_by_phone(params[:From])
    if nil == @customer
      sms_response "BACE: We don't recognize this phone number, please add it to your profile"
    end

    command = params[:Body].downcase.split
    case command.shift
    when /^b/
      sms_response "BACE: Your balance is #{@customer.account.balance}"
    when /^p/
      if (command.length < 2)
        sms_response "BACE: We didn't get enough information. To pay someone text 'pay 555-555-5555 ##'"
      elsif /(^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$)/ =~ command[0]
        @worker = Person.find_by_email(command[0])
      else
        @worker = Person.find_by_phone(command[0].normalize_phone!)
      end

      if nil == @worker
        sms_response "BACE: Bad email address or phone number when trying to pay. You entered: '" + command[0] + "'"
      end

      if /^\d+$/ !~ command[1]
        sms_response "BACE: Please enter a valid number of hours to pay. You entered: '" + command[1] + "'"
      end
      amount = command[1].to_i

      memo = command[2, command.length]
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
        sms_response "BACE: Something went wrong sending your payment of #{command[1]} hours to #{command[0]}. Please try again"
      end

      ### TODO: what language to use
      sms_response "BACE: You paid #{command[1]} hours to #{command[0]}"
    end
  end

  private
    def sms_response(text)
      Twilio.connect(ENV['TWILIO_KEY'], ENV["TWILIO_SECRET"])
      Twilio::Sms.message(ENV["TWILIO_NUMBER"], @from_phone, text)
      return render :nothing => true
    end
end
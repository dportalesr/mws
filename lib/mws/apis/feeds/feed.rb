require 'nokogiri'

module Mws::Apis::Feeds

  class Feed

    Type = Mws::Enum.for(
      product: '_POST_PRODUCT_DATA_', 
      product_relationship: '_POST_PRODUCT_RELATIONSHIP_DATA_', 
      item: '_POST_ITEM_DATA_', 
      override: '_POST_PRODUCT_OVERRIDES_DATA_', 
      image: '_POST_PRODUCT_IMAGE_DATA_', 
      price: '_POST_PRODUCT_PRICING_DATA_', 
      inventory: '_POST_INVENTORY_AVAILABILITY_DATA_', 
      order_acknowledgement: '_POST_ORDER_ACKNOWLEDGEMENT_DATA_', 
      order_fufillment: '_POST_ORDER_FULFILLMENT_DATA_', 
      fulfillment_order_request: '_POST_FULFILLMENT_ORDER_REQUEST_DATA_', 
      fulfillment_order_cancellation: '_POST_FULFILLMENT_ORDER_CANCELLATION_REQUEST_DATA'
    )

    attr_accessor :merchant_id, :purge_and_replace, :messages

    Mws::Enum.sym_reader self, :message_type

    def initialize(options={}, &block)
      @merchant = options[:merchant]
      @message_type = Message::Type.for(options[:message_type])
      @purge_and_replace = options[:purge_and_replace] || false

      @messages = []

      instance_eval &block if block_given?
    end

    def xml_for
      builder = Nokogiri::XML::Builder.new do | builder |
        builder.AmazonEnvelope('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:noNamespaceSchemaLocation' => 'amznenvelope.xsd') {
          builder.Header {
            builder.DocumentVersion '1.01'
            builder.MerchantIdentifier @merchant
          }
          builder.MessageType @message_type.val
          builder.PurgeAndReplace @purge_and_replace
          @messages.each do | message |
            message.xml_for builder
          end
        }
      end
      builder.to_xml
    end 

    def message(sku, operation_type, &body_builder)
      message = Message.new @messages.length + 1, sku, operation_type, body_builder
      @messages << message
      message
    end

    class Message

      Type = Mws::Enum.for(
        fufillment_center: 'FulfillmentCenter',
        inventory: 'Inventory', 
        listings: 'Listings', 
        order_acknowledgement: 'OrderAcknowledgement', 
        order_adjustment: 'OrderAdjustment', 
        order_fulfillment: 'OrderFulfillment', 
        override: 'Override', 
        price: 'Price',
        processing_report: 'ProcessingReport',
        product: 'Product',
        image: 'ProductImage',
        relationship: 'Relationship',
        settlement_report: 'SettlementReport'
      )

      OperationType = Mws::Enum.for(
        update: 'Update', 
        delete: 'Delete', 
        partial_update: 'PartialUpdate'
      )

      attr_accessor :id, :sku, :body_builder

      Mws::Enum.sym_reader self, :operation_type

      def initialize(id, sku, operation_type, body_builder)
        @id = id
        @sku = sku
        @operation_type = OperationType.for(operation_type)
        @body_builder = body_builder
      end

      def xml_for(builder)
        builder.Message {
          builder.MessageID @id
          builder.OperationType @operation_type.val
          @body_builder.call builder
        }
      end
    end

  end

end
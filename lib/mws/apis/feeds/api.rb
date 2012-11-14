module Mws::Apis::Feeds

  class Api

    attr_accessor :products, :images, :prices, :inventory, :shipping

    def initialize(connection, defaults={})
      @connection = connection
      defaults[:version] ||= '2009-01-01'
      @defaults = defaults
      
      @products = TargetedApi.new self, defaults[:merchant], :product
      @images = TargetedApi.new self, defaults[:merchant], :image
      @prices = TargetedApi.new self, defaults[:merchant], :price
      @shipping = TargetedApi.new self, defaults[:merchant], :override
      @inventory = TargetedApi.new self, defaults[:merchant], :inventory
    end

    def get(id)
      node = @connection.get('/', { feed_submission_id: id }, @defaults.merge(
        action: 'GetFeedSubmissionResult',
        xpath: 'AmazonEnvelope/Message'
      ))
      SubmissionResult.from_xml node
    end

    def submit(body, params)
      params[:feed_type] = Feed::Type.for(params[:feed_type]).val
      doc = @connection.post('/', params, body, @defaults.merge( action: 'SubmitFeed'))
      SubmissionInfo.from_xml doc.xpath('FeedSubmissionInfo').first
    end

    def cancel(options={})

    end

    def list(params={})
      params[:feed_submission_id] ||= params.delete(:ids) || [ params.delete(:id) ].flatten.compact
      doc = @connection.get('/', params, @defaults.merge(action: 'GetFeedSubmissionList'))
      doc.xpath('FeedSubmissionInfo').map do | node |
        SubmissionInfo.from_xml node
      end
    end

    def count()
      @connection.get('/', {}, @defaults.merge(action: 'GetFeedSubmissionCount')).xpath('Count').first.text.to_i
    end

  end

  class TargetedApi

    def initialize(feeds, merchant, type)
      @feeds = feeds
      @merchant = merchant
      @message_type = Feed::Message::Type.for(type)
      @feed_type = Feed::Type.for(type)
    end

    def add(*resources)
      submit resources, :update, true 
    end

    def update(*resources)
      submit resources, :update
    end

    def patch(*resources)
      raise 'Operation Type not supported.' unless @feed_type == Feed::Type.PRODUCT
      submit resources, :partial_update
    end

    def delete(*resources)
      submit resources, :delete
    end

    def submit(resources, def_operation_type=nil, purge_and_replace=false)
      root = @message_type.val
      messages = []
      feed = Feed.new merchant: @merchant, message_type: @message_type do
        resources.each do | resource |
          operation_type = def_operation_type
          if resource.respond_to?(:operation_type) and resource.operation_type
            operation_type = resource.operation_type
          end 
          messages << message(resource.sku, operation_type) do | builder |
            resource.to_xml root, builder
          end
        end
      end
      Transaction.new @feeds.submit(feed.xml_for, feed_type: @feed_type, purge_and_replace: purge_and_replace) do 
        messages.each_with_index do | message, index |
          resource = resources[index]
          item message.id, message.sku, message.operation_type, resource.respond_to?(:type) ? resource.type : nil
        end
      end
    end

  end

end
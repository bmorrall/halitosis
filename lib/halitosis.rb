# frozen_string_literal: true

require_relative "halitosis/version"

require "json"

# HAL-like JSON generator
#
# Provides an interface for serializing resources as JSON
# with HAL-like links and relationships.
#
# @example
#   class ArticleSerializer
#     include Halitosis
#
#     resource :article
#
#     property :id, required: true
#
#     property :title
#
#     link :self, -> { article_path(article) }
#
#     link :external, optional: true, -> { "http://example.com/read/#{article.id}" }
#
#     rel :author, -> { UserSerializer.new(article.author) }
#     # or relatioinship :author, -> { UserSerializer.new(article.author) }
#   end
#
#   render json: ArticleSerializer.new(article, include: :author, fields: :title)
module Halitosis
  def self.included(base)
    base.extend ClassMethods

    base.include Base

    config.extensions.each { |extension| base.send :include, extension }
  end

  module ClassMethods
    def resource(name)
      include Halitosis::Resource

      define_resource(name)
    end

    def collection(name, ...)
      include Halitosis::Collection

      define_collection(name, ...)
    end
  end

  class << self
    # @yield [Halitosis::Configuration] configuration instance for modification
    #
    def configure
      yield config
    end

    # Configuration instance
    #
    # @return [Halitosis::Configuration]
    #
    def config
      @config ||= Configuration.new
    end
  end
end

require_relative "halitosis/base"
require_relative "halitosis/errors"
require_relative "halitosis/field"
require_relative "halitosis/fields"
require_relative "halitosis/properties"
require_relative "halitosis/links"
require_relative "halitosis/meta"
require_relative "halitosis/permissions"
require_relative "halitosis/relationships"
require_relative "halitosis/resource"
require_relative "halitosis/collection"
require_relative "halitosis/hash_util"
require_relative "halitosis/configuration"

require "halitosis/railtie" if defined?(::Rails)

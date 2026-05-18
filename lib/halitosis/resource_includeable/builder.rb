# frozen_string_literal: true

module Halitosis
  module ResourceIncludeable
    class Builder < Halitosis::Includeable::Builder
      private

      def field_class
        ResourceIncludeable::Field
      end
    end
  end
end

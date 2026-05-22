class ValidationErrorsController < ApplicationController
  def create
    example = Example.new
    example.errors.add(:name, :blank)
    example.errors.add(:base, "You are not permitted to perform this action")

    render renderable: Halitosis::ErrorsSerializer.new(example.errors, param: "example"),
      status: :unprocessable_entity
  end

  def json_create
    example = Example.new
    example.errors.add(:name, :blank)
    example.errors.add(:base, "You are not permitted to perform this action")

    render json: Halitosis::ErrorsSerializer.new(example.errors, param: "example"),
      status: :unprocessable_entity
  end
end

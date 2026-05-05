# frozen_string_literal: true

class PagePolicy < ApplicationPolicy
  def index?
    flag_active? && (user.role_admin_for?(seller) || user.role_marketing_for?(seller))
  end

  def create?
    index?
  end

  def new?
    create?
  end

  def edit?
    create?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  private
    def flag_active?
      Feature.active?(:pages, seller)
    end
end

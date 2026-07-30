# frozen_string_literal: true

Rails.application.routes.draw do
  mount_i18n_proofreading at: '/i18n_proofreading'
  get 'sample', to: 'sample#show'
end

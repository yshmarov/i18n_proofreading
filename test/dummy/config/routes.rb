# frozen_string_literal: true

Rails.application.routes.draw do
  mount I18nProofreading::Engine => '/i18n_proofreading'
  get 'sample', to: 'sample#show'
end

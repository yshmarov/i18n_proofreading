# frozen_string_literal: true

class SampleController < ActionController::Base
  # Module scripts use a CORS fetch rather than an XMLHttpRequest. This action
  # serves a public test asset, so Rails' JavaScript response guard is unnecessary.
  skip_after_action :verify_same_origin_request, only: :turbo

  # `page_lang` lets a spec render the page in one language while the ambient
  # I18n.locale is something else — reproducing an app that switches locale in an
  # `around_action` (so the locale is reset by the time the widget is injected).
  def show
    @page_lang = params[:page_lang] || I18n.locale
    render status: request.post? ? 422 : 200, inline: <<~ERB
      <!DOCTYPE html>
      <html lang="<%= @page_lang %>">
        <head>
          <meta name="csrf-token" content="test">
          <% if params[:turbo] %>
            <% if params[:morph] %><meta name="turbo-refresh-method" content="morph"><% end %>
            <script src="/sample/turbo.js" type="module"></script>
          <% end %>
        </head>
        <body>
          <h1><%= t("sample.greeting") %></h1>
          <% if params[:turbo] %>
            <a id="onward" href="/sample?turbo=1&unavailable=1&page=next">Onward</a>
            <form action="/sample?turbo=1" method="post">
              <button type="submit">Validate</button>
            </form>
            <% if request.post? %><p id="validation-error">Please try again</p><% end %>
          <% end %>
        </body>
      </html>
    ERB
  end

  # Serve the real Turbo browser code only for system-test fixtures; the engine
  # and the plain sample page still have no Turbo or asset-pipeline dependency.
  def turbo
    send_file File.join(Gem.loaded_specs.fetch('turbo-rails').full_gem_path,
                        'app/assets/javascripts/turbo.js'), type: 'text/javascript', disposition: 'inline'
  end
end

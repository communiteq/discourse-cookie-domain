# frozen_string_literal: true

# name: discourse-cookie-domain
# about: Change the cookie domain
# version: 1.1
# authors: Communiteq
# url: TODO

enabled_site_setting :cookie_domain_enabled

module ::DiscourseCookieDomain
  PLUGIN_NAME = "discourse-cookie-domain"
end

after_initialize do
  module DiscourseCookieDomain::DefaultCurrentUserProviderExtension
    def log_off_user(session, cookie_jar)
      if SiteSetting.cookie_domain_enabled && !SiteSetting.cookie_domain_domain.empty?
        cookie_jar.delete(Auth::DefaultCurrentUserProvider::TOKEN_COOKIE, { domain: SiteSetting.cookie_domain_domain })
        SiteSetting.cookie_domain_remove_cookies_on_logout.split('|').each do |c|
          cookie_jar.delete(c, { domain: SiteSetting.cookie_domain_domain })
        end
      end
      super
    end

    def set_auth_cookie!(unhashed_auth_token, user, cookie_jar)
      data = {
        token: unhashed_auth_token,
        user_id: user.id,
        username: user.username,
        trust_level: user.trust_level,
        issued_at: Time.zone.now.to_i,
      }

      expires = SiteSetting.maximum_session_age.hours.from_now if SiteSetting.persistent_sessions

      same_site = SiteSetting.same_site_cookies if SiteSetting.same_site_cookies != "Disabled"

      cookie_data = {
        value: data,
        httponly: true,
        secure: SiteSetting.force_https,
        expires: expires,
        same_site: same_site,
      }
      if SiteSetting.cookie_domain_enabled
        cookie_data[:domain] = SiteSetting.cookie_domain_domain unless SiteSetting.cookie_domain_domain.empty?
      end
      cookie_jar.encrypted[Auth::DefaultCurrentUserProvider::TOKEN_COOKIE] = cookie_data
    end
  end

  reloadable_patch do
    Auth::DefaultCurrentUserProvider.prepend(DiscourseCookieDomain::DefaultCurrentUserProviderExtension)
  end
end

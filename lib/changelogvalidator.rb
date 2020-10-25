# frozen_string_literal: true

require 'sinatra'

require_relative 'changelogvalidator/vcs'
require_relative 'changelogvalidator/hmac'

get '/' do
  'Alive'
end

post '/handler' do
  return halt 500, "Signatures didn't match!" unless validate_request(request)

  payload = JSON.parse(params[:payload])

  case request.env['HTTP_X_GITHUB_EVENT']
  when 'pull_request'
    if %w[labeled unlabeled opened reopened synchronize].include?(payload['action'])
      vcs = ChangelogValidator::Vcs.new(token: ENV['GITHUB_TOKEN'], pull_request: payload['pull_request'])
      return 'Only runs on Default branch' unless vcs.default_branch_target?

      vcs.status_check(state: 'pending')
      if vcs.changelog_unreleased_entry?
        vcs.status_check(state: 'success')
        return 'Has unreleased entry'
      else
        vcs.status_check(state: 'failure')
        return 'Does not have unreleased entry'
      end
    end
  end
end

def validate_request(request)
  true unless ENV['SECRET_TOKEN']
  request.body.rewind
  payload_body = request.body.read
  verify_signature(payload_body)
end

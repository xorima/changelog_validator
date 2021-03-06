# frozen_string_literal: true

require 'octokit'

module ChangelogValidator
  # Used to handle calls to VCS
  class Vcs
    def initialize(token:, pull_request:, changelog_name: 'CHANGELOG.md')
      @client = Octokit::Client.new(access_token: token)
      @repository_name = pull_request['base']['repo']['full_name']
      @pull_request = pull_request
      @changelog_name = changelog_name
      @comment_base = 'Unable to find section ## Unreleased in'
    end

    def default_branch_target?
      @pull_request['base']['ref'] == @pull_request['base']['repo']['default_branch']
    end

    def changelog_unreleased_entry?
      file = get_file_contents(@changelog_name)
      check_for_entry?(file['content'])
    end

    def status_check(state:)
      raise ArgumentError, 'State must be pending, success, failure' unless %w[pending success failure].include?(state)

      @client.create_status(@repository_name,
                            @pull_request['head']['sha'],
                            state,
                            { context: 'Changelog Validator',
                              description: "Checking the #{@changelog_name} has an entry under ## Unreleased" })
    end

    def check_for_entry?(changelog)
      result = /##\s+(Unreleased)([\s\S]*?)(\n##\s+\d+\.\d+\.\d+|\Z)/im.match(changelog)
      return true if result

      false
    end

    private

    def get_file_contents(file_path)
      file_content = @client.contents(@repository_name, path: file_path, ref: @pull_request['head']['sha'])
      content = Base64.decode64(file_content[:content])
      response = {}
      response['content'] = content
      response['sha'] = file_content[:sha]
      response
    end
  end
end

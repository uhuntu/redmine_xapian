# encoding: utf-8
# frozen_string_literal: true
#
# Redmine Xapian is a Redmine plugin to allow attachments searches by content.
#
# Copyright © 2010    Xabier Elkano
# Copyright © 2015-22 Karel Pičman <karel.picman@kontron.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'uri'
require 'xapian'

module RedmineXapian
  include ContainerTypeHelper
  module XapianSearch

    def xapian_search(tokens, limit_options, projects_to_search, all_words, user, xapian_file)
      Rails.logger.info 'XapianSearch::xapian_search'
      xpattachments = []
      return nil unless Setting.plugin_redmine_xapian['enable']
      Rails.logger.info "Global settings dump #{Setting.plugin_redmine_xapian.inspect}"
      stemming_lang = Setting.plugin_redmine_xapian['stemming_lang'].rstrip
      Rails.logger.info "stemming_lang: #{stemming_lang}"
      stemming_strategy = Setting.plugin_redmine_xapian['stemming_strategy'].rstrip
      Rails.logger.info "stemming_strategy: #{stemming_strategy}"
      databasepath = get_database_path(xapian_file)
      Rails.logger.info "databasepath: #{databasepath}"
      
      begin
        database = Xapian::Database.new(databasepath)
        Rails.logger.info "Can open Xapian database #{databasepath}"
      rescue => e
        Rails.logger.error "Can't open Xapian database #{databasepath} - #{e.inspect}"
        return nil
      end

      # Start an enquire session.
      enquire = Xapian::Enquire.new(database)

      # Combine the rest of the command line arguments with spaces between
      # them, so that simple queries don't have to be quoted at the shell
      # level.
      query_string = tokens.map{ |x| !(x[-1,1].eql?'*')? x+'*': x }.join(' ')
      # Parse the query string to produce a Xapian::Query object.
      qp = Xapian::QueryParser.new
      stemmer = Xapian::Stem.new(stemming_lang)
      qp.stemmer = stemmer
      qp.database = database
      case stemming_strategy
        when 'STEM_NONE'
          qp.stemming_strategy = Xapian::QueryParser::STEM_NONE
        when 'STEM_SOME'
          qp.stemming_strategy = Xapian::QueryParser::STEM_SOME
        when 'STEM_ALL'
          qp.stemming_strategy = Xapian::QueryParser::STEM_ALL
      end
      if all_words
        qp.default_op = Xapian::Query::OP_AND
      else
        qp.default_op = Xapian::Query::OP_OR
      end

      flags = Xapian::QueryParser::FLAG_WILDCARD
      flags |= Xapian::QueryParser::FLAG_CJK_NGRAM if Setting.plugin_redmine_xapian['enable_cjk_ngrams']
      query = qp.parse_query(query_string, flags)
      Rails.logger.info "query_string is: #{query_string}"
      Rails.logger.info "Parsed query is: #{query.description}"

      # Find the top 100 results for the query.
      enquire.query = query
      matchset = enquire.mset(0, 1000)

      return nil if matchset.nil?

      # Display the results.
      Rails.logger.info "Matches 1-#{matchset.size} records:"
      Rails.logger.info "Searching for #{(xapian_file == 'Repofile') ? 'repofiles' : 'attachments'}"
      i = 0
      p = URI::Parser.new

      matchset.matches.each do |m|
        if xapian_file == 'Repofile'
          if m.document.data =~ /^date=(.+)\W+sample=(.+)\W+url=(.+)\W/
            dochash = { date: $1, sample: $2, url: p.unescape($3) }
            repo_file = process_repo_file(projects_to_search, dochash, user, i)
            if repo_file
              xpattachments << repo_file
              i = i + 1
            end
          else
            Rails.logger.error "Wrong format of document data: #{m.document.data}"
          end
        elsif xapian_file == 'Attachment'
          if m.document.data =~ /^url=(.+)\W+sample=(.+)\W+(author|type|caption|modtime|size)=/
            url = p.unescape($1)
            sample = $2
            if url.include?("png.txt") || url.include?("jpg.txt")
              url = url.chomp(".txt")
              Rails.logger.info url
            end
            dochash = { url: url, sample: sample }
            Rails.logger.info "dochash = #{dochash}"
            attachment = process_attachment(projects_to_search, dochash, user)
            if attachment
              xpattachments << attachment
            end
          else
            Rails.logger.error "Wrong format of document data: #{m.document.data}"
          end
        end
      end
      Rails.logger.info 'Xapian searched'
      xpattachments.map{ |a| [a.created_on, a.id] }
    end

  private

    def process_attachment(projects, dochash, user)
      attachment = Attachment.where(disk_filename: dochash[:url].split('/').last).first
      if attachment
        Rails.logger.info "Attachment created on #{attachment.created_on}"
        Rails.logger.info "Attachment's project #{attachment.project}"
        Rails.logger.info "Attachment's docattach not nil..:  #{attachment}"
        if attachment.container
          Rails.logger.info 'Adding attachment'
          project = attachment.project
          container_type = attachment[:container_type]
          container_permission = ContainerTypeHelper.to_permission(container_type)
          can_view_container = user.allowed_to?(container_permission, project)

          if container_type == 'Issue'
            issue = Issue.find_by(id: attachment[:container_id])
            allowed = can_view_container && issue && issue.visible?
          else
            allowed = can_view_container
          end

          projects = [] << projects if projects.is_a?(Project)
          project_ids = projects.collect(&:id) if projects

          if allowed
            if project_ids.blank? || (attachment.project && project_ids.include?(attachment.project.id))
              Redmine::Search.cache_store.write("Attachment-#{attachment.id}",
                dochash[:sample].force_encoding('UTF-8')) if dochash[:sample]
              return attachment
            end
          else
            Rails.logger.info 'User without permissions for process attachment in xapian search'
          end
        end
      end
      nil
    end

    def process_repo_file(projects, dochash, user, id)
      Rails.logger.info "Repository file: #{dochash[:url]}"
      Rails.logger.info "Repository date: #{dochash[:date]}"
      Rails.logger.info "Repository sample field: #{dochash[:sample]}"
      repository_attachment = nil
      if dochash[:url] =~ /^#{Redmine::Utils::relative_url_root}\/projects\/(.+)\/repository\/(?:revisions\/(.*)\/|([a-zA-Z_0-9]*)\/)?(?:revisions\/(.*))?\/?entry\/(?:(?:branches|tags)\/(.+?)\/)?(.+?)(?:\?rev=(.*))?$/
        repo_project_identifier = $1
        Rails.logger.info "Project identifier: #{repo_project_identifier}"
        repo_identifier = $3
        Rails.logger.info "Repository identifier: #{repo_identifier}"
        repo_filename = $6
        Rails.logger.info "Repository file: #{repo_filename}"
        repo_revision = (!$2.nil? ? $2 : '') + (!$4.nil? ? $4 : '') + (!$5.nil? ? $5 : '') +(!$7.nil? ? $7 : '')
        Rails.logger.info "Repository revision: #{repo_revision}"
        project = Project.where(identifier: repo_project_identifier).first
        if project
          if repo_identifier != ''
            repository = Repository.where(project_id: project.id, identifier: repo_identifier).first if project
          else
            repository = Repository.where(project_id: project.id).first if project
          end
          if repository
            Rails.logger.info "Repository found #{repository.identifier}"
            projects = [] << projects if projects.is_a?(Project)
            project_ids = projects.collect(&:id) if projects
            allowed = user.allowed_to?(:browse_repository, repository.project)

            if allowed
              if project_ids.blank? || (project_ids.include?(project.id))
                repository_attachment = Repofile.new
                repository_attachment.filename = repo_filename
                begin
                  repository_attachment.created_on = dochash[:date].to_datetime
                rescue => e
                  Rails.logger.error e.message
                  repository_attachment.created_on = Time.at(0)
                end
                repository_attachment.project_id = project.id
                if dochash[:sample]
                  if dochash[:sample].encoding.to_s != 'UTF-8'
                    repository_attachment.description = dochash[:sample].force_encoding('UTF-8')
                  else
                    repository_attachment.description = dochash[:sample]
                  end
                end
                repository_attachment.repository_id = repository.id
                repository_attachment.id = id
                repository_attachment.url = dochash[:url]
                repository_attachment.revision = repo_revision
                h = { filename: repository_attachment.filename, created_on: repository_attachment.created_on.to_s,
                      project_id: repository_attachment.project_id, description: repository_attachment.description,
                      repository_id: repository_attachment.repository_id, url: repository_attachment.url,
                      revision: repository_attachment.revision }
                Redmine::Search.cache_store.write "Repofile-#{repository_attachment.id}", h.to_s
              else
                Rails.logger.warn 'No projects to search in'
              end
            else
              Rails.logger.warn 'User without :browse_repository permissions'
            end
          else
            Rails.logger.error "Repository not found"
          end
        else
          Rails.logger.error "Project #{repo_project_identifier} not found"
        end
      else
        Rails.logger.error 'Wrong format of the URL'
      end
      repository_attachment
    end

    def get_database_path(xapian_file)
      if xapian_file == 'Repofile'
        File.join Setting.plugin_redmine_xapian['index_database'].rstrip, 'repodb'
      else
        File.join Setting.plugin_redmine_xapian['index_database'].rstrip,
          Setting.plugin_redmine_xapian['stemming_lang'].rstrip
      end
    end

  end

end

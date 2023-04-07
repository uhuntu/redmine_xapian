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

class Repofile
  include RedmineXapian
  include ActiveModel::Model
  include ActiveRecord::Reflection
  include Redmine::Acts::Searchable

  acts_as_searchable columns: ['filename', 'description'],
                     permission: :browse_repository, date_column: :created_on, project_key: :project_id

  attr_accessor :id
  attr_accessor :description
  attr_accessor :created_on
  attr_accessor :project_id
  attr_accessor :filename
  attr_accessor :repository_id   
  attr_accessor :url 
  attr_accessor :revision

  def event_title    
    filename.force_encoding 'UTF-8'
  end

  def event_datetime    
    created_on
  end

  def event_url
    url.force_encoding 'UTF-8'
  end

  def event_description
    description.force_encoding 'UTF-8'
  end
	 
  def event_type
    repo_type
  end

  def repo_type
    repository.type.split('::')[1].downcase
  end 
  
  def project    
    @project = Project.find_by(id: project_id) unless @project
    @project
  end
  
  def repository
    @repository = Repository.find_by(id: repository_id) unless @repository
    @repository
  end
  
  def identifier
    revision.to_s
  end  

  def format_identifier
    identifier
  end

  def self.search_result_ranks_and_ids(tokens, user = User.current, projects = nil, options = {})      
    r = search tokens, user, projects, options
    r.map{ |x| [x[0].to_i, x[1]] }
  end
  
  def self.search_results_from_ids(ids)    
    results = []
    ids.each do |id|
      key = "Repofile-#{id}"
      value = Redmine::Search.cache_store.fetch key
      if value
        attributes = eval value
        repofile = Repofile.new        
        repofile.id = id
        repofile.filename = attributes[:filename]
        repofile.created_on = attributes[:created_on].to_datetime
        repofile.project_id = attributes[:project_id]
        repofile.description = attributes[:description]
        repofile.repository_id = attributes[:repository_id]
        repofile.url = attributes[:url]
        repofile.revision = attributes[:revision]
        results << repofile
        Redmine::Search.cache_store.delete key
      end
    end  
    results
  end
  
  private
  
  def self.search(tokens, user, projects, options)     
    Rails.logger.info 'Repository::search'
    search_data = SearchData.new self, tokens, projects, options, user, name
    search_results = []
    unless options[:titles_only]
      Rails.logger.info "Call xapian search service for #{name.inspect}"          
      xapian_results = XapianSearchService.search search_data
      search_results.concat xapian_results unless xapian_results.blank?
      Rails.logger.info "Call xapian search service for  #{name.inspect} completed"          
    end
    search_results
  end           

end

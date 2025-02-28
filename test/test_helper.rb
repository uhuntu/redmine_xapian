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

require 'simplecov'

SimpleCov.start do
  add_group 'Models', 'plugins/redmine_xapian/app/models'
  add_group 'Views', 'plugins/redmine_xapian/app/views'
  add_group 'Config', 'plugins/redmine_xapian/config'
  add_group 'Library', 'plugins/redmine_xapian/lib'
  add_group 'Test', 'plugins/redmine_xapian/test'
end

# Load the normal Rails helper
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

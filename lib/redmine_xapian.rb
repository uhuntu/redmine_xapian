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

# Libraries
require File.dirname(__FILE__) + '/redmine_xapian/search_data'
require File.dirname(__FILE__) + '/redmine_xapian/xapian_search_service'

# Patches
require File.dirname(__FILE__) + '/redmine_xapian/patches/attachment_patch'
require File.dirname(__FILE__) + '/redmine_xapian/patches/search_controller_patch'

# Hooks
# Views
require File.dirname(__FILE__) + '/redmine_xapian/hooks/views/base_view_hooks'
#
# Copyright 2015 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

module Actions
  module Fusor
    module Deployment
      module PrepareOrg
        class CreateProduct < Actions::Fusor::FusorActionWithSubPlans
          def humanized_name
            _("Create Product")
          end

          def plan(deployment)
            super(deployment)
            plan_self(:deployment_id => deployment.id)
          end

          def create_sub_plans
            unless ::Katello::Product.find_by_name('Fusor')
              deployment = ::Fusor::Deployment.find(input[:deployment_id])
              org = deployment.organization
              product = ::Katello::Product.new({:name => 'Fusor', :organization_id => org.id})
              trigger(::Actions::Katello::Product::Create, product, org)
            end
          end
        end
      end
    end
  end
end
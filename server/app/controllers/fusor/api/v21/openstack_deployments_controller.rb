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

module Fusor
  class Api::V21::OpenstackDeploymentsController < Api::V21::BaseController

    resource_description do
      name 'OpenStack Deployments'
      desc 'Contains all the configuration options for an OpenStack deployment as part of a Fusor deployment.'
      api_version 'fusor_v21'
      api_base_url '/fusor/api/v21'
    end

    def_param_group :openstack_deployment do
      param :undercloud_admin_password, String, desc: 'password for the admin account on the undercloud'
      param :undercloud_ip_address, String, desc: 'IP Address or hostname of the undercloud'
      param :undercloud_ssh_username, String, desc: 'Username to SSH into the undercloud'
      param :undercloud_ssh_password, String, desc: 'Password to SSH into the undercloud'
      param :overcloud_deployed, :bool, desc: 'Does the undercloud have an existing deployed overcloud'
      param :overcloud_ext_net_interface, String, desc: 'Interface to provide external network access for the overcloud'
      param :overcloud_private_net, String, desc: 'CIDR notated network range for the overcloud private IP addresses'
      param :overcloud_float_net, String, desc: 'CIDR notated network range for the overcloud floating IP addresses'
      param :overcloud_float_gateway, String, desc: 'IP address of the gateway for the overcloud floating network'
      param :overcloud_password, String, desc: 'Password for the admin account on the overcloud'
      param :overcloud_libvirt_type, String, desc: 'Overcloud virtualization type (kvm)'
      param :overcloud_node_count, Integer, desc: 'Total number of registered nodes'
      param :overcloud_compute_flavor, String, desc: 'Flavor assigned to overcloud compute nodes'
      param :overcloud_compute_count, Integer, desc: 'Number of overcloud compute nodes to be deployed'
      param :overcloud_controller_flavor, String, desc: 'Flavor assigned to overcloud controller nodes'
      param :overcloud_controller_count, Integer, desc: 'Number of overcloud controller nodes to be deployed'
      param :overcloud_ceph_storage_flavor, String, desc: 'Flavor assigned to overcloud ceph storage nodes'
      param :overcloud_ceph_storage_count, Integer, desc: 'Number of overcloud compute ceph storage to be deployed'
      param :overcloud_block_storage_flavor, String, desc: 'Flavor assigned to overcloud block storage nodes'
      param :overcloud_block_storage_count, Integer, desc: 'Number of overcloud block storage nodes to be deployed'
      param :overcloud_object_storage_flavor, String, desc: 'Flavor assigned to overcloud object storage nodes'
      param :overcloud_object_storage_count, Integer, desc: 'Number of overcloud object storage nodes to be deployed'
      param :external_ceph_storage, :bool, desc: 'Will the overcloud use an externally hosted Ceph storage device'
      param :ceph_ext_mon_host, String, desc: 'Location of the externally hosted Ceph storage device'
      param :ceph_cluster_fsid, String, desc: 'Cluster FSID of the externally hosted Ceph storage device'
      param :ceph_client_username, String, desc: 'Username to log into the externally hosted Ceph storage device'
      param :ceph_client_key, String, desc: 'Client key used to log into the externally hosted Ceph storage device'
      param :nova_rdb_pool_name, String, desc: 'Nova RDB pool name is required when using external ceph storage (vms)'
      param :cinder_rdb_pool_name, String, desc: 'Cinder RDB pool name is required when using external ceph storage (volumes)'
      param :glance_rdb_pool_name, String, desc: 'Glance RDB pool name is required when using external ceph storage (images)'
    end

    api :GET, '/openstack_deployments', 'Gets a list of OpenStack deployments'
    param :deployment_id, Integer, desc: 'ID of the deployment the OpenStack deployments are associated with'
    def index
      if params[:deployment_id]
        @openstack_deployments = Fusor::OpenstackDeployment.where(:deployment_id => params[:deployment_id])
      else
        @openstack_deployments = OpenstackDeployment.all
      end
      render :json => @openstack_deployments, :each_serializer => Fusor::OpenstackDeploymentSerializer, :serializer => RootArraySerializer
    end

    api :POST, '/openstack_deployments', 'Create a OpenStack deployment'
    param_group :openstack_deployment
    def create
      @openstack_deployment = Fusor::OpenstackDeployment.new(openstack_deployment_params)
      if @openstack_deployment.save
        render :json => @openstack_deployment, :serializer => Fusor::OpenstackDeploymentSerializer
      else
        render json: {errors: @openstack_deployment.errors}, status: 422
      end
    end

    api :GET, '/openstack_deployments/:id', 'Show a OpenStack deployment'
    param :id, Integer, required: true, desc: 'ID of the OpenStack deployment'
    def show
      @openstack_deployment = Fusor::OpenstackDeployment.find(params[:id])
      render :json => @openstack_deployment, :serializer => Fusor::OpenstackDeploymentSerializer
    end

    api :PUT, '/openstack_deployments', 'Update a OpenStack deployment'
    param :id, Integer, required: true, desc: 'ID of the OpenStack deployment'
    param_group :openstack_deployment
    def update
      @openstack_deployment = Fusor::OpenstackDeployment.find(params[:id])

      @openstack_deployment.attributes = openstack_deployment_params
      @openstack_deployment.save(:validate => false)

      render :json => @openstack_deployment, :serializer => Fusor::OpenstackDeploymentSerializer
    end

    api :DELETE, '/openstack_deployments/:id', 'Delete a OpenStack deployment'
    param :id, Integer, required: true, desc: 'ID of the OpenStack deployment'
    def destroy
      @openstack_deployment = Fusor::OpenstackDeployment.find(params[:id])
      @openstack_deployment.destroy
      render json: {}, status: 204
    end

    api :POST, '/openstack_deployments/:id/sync_openstack', 'Synchronize a Openstack deployment object with the OpenStack deployment plan'
    param :id, Integer, required: true, desc: 'ID of the OpenStack deployment'
    def sync_openstack
      @openstack_deployment = Fusor::OpenstackDeployment.find(params[:id])

      @openstack_deployment.overcloud_deployed = undercloud_handle.list_stacks.present?
      @openstack_deployment.save(:validate => false)

      return render json: {errors: @openstack_deployment.errors}, status: 422 unless @openstack_deployment.valid?

      undercloud_handle.edit_plan_environments('overcloud', {'environments/puppet-ceph-external.yaml' => @openstack_deployment.external_ceph_storage,
                                                             'environments/rhel-registration.yaml' => true,
                                                             'environments/enable-tls.yaml' => true,
                                                             'environments/inject-trust-anchor.yaml' => true })
      ssl_params = build_openstack_ssl_params
      undercloud_handle.edit_plan_parameters('overcloud', ssl_params.merge(build_openstack_params))
      sync_failures = get_sync_failures(ssl_params)
      return render json: {errors: sync_failures}, status: 500 unless sync_failures.empty?

      render json: {}, status: 200
    end

    private

    def undercloud_handle
      Overcloud::UndercloudHandle.new('admin', @openstack_deployment.undercloud_admin_password, @openstack_deployment.undercloud_ip_address, 5000)
    end

    def build_openstack_ssl_params
      deployment = Fusor::OpenstackDeployment.find(params[:id]).deployment
      certs = Utils::Fusor::OvercloudSSL.new(deployment).gen_certs
      {'CloudName' => "#{deployment.label.tr('_', '-')}-overcloud.#{Domain.find(Hostgroup.find_by_name('Fusor Base').domain_id)}",
       'SSLRootCertificate' => certs['ca'], 'SSLCertificate' => certs['cert'], 'SSLKey' => certs['key']}
    end

    def build_openstack_params
      deployment = Fusor::OpenstackDeployment.find(params[:id]).deployment
      osp_params = {'rhel_reg_sat_repo' => 'rhel-7-server-satellite-tools-6.2-rpms',
                    'rhel_reg_org' => 'Default_Organization',
                    'rhel_reg_method' => 'satellite',
                    'rhel_reg_sat_url' => Setting[:foreman_url],
                    'rhel_reg_activation_key' => "OpenStack_Undercloud-#{deployment.label}-OpenStack_Undercloud"}
      Fusor::OpenstackDeployment::OVERCLOUD_ATTR_PARAM_HASH.each { |attr_name, param_name| osp_params[param_name] = @openstack_deployment.send(attr_name) }
      if @openstack_deployment.external_ceph_storage
        Fusor::OpenstackDeployment::CEPH_ATTR_PARAM_HASH.each { |attr_name, param_name| osp_params[param_name] = @openstack_deployment.send(attr_name) }
      end
      osp_params
    end

    def get_sync_failures(ssl_params)
      plan = undercloud_handle.get_plan_parameters('overcloud')
      errors = {}
      attr_param_hash = Fusor::OpenstackDeployment::OVERCLOUD_ATTR_PARAM_HASH
      attr_param_hash = attr_param_hash.merge(Fusor::OpenstackDeployment::CEPH_ATTR_PARAM_HASH) if @openstack_deployment.external_ceph_storage
      attr_param_hash = attr_param_hash.except(:overcloud_ceph_storage_flavor) unless @openstack_deployment.overcloud_ceph_storage_count > 0
      attr_param_hash = attr_param_hash.except(:overcloud_block_storage_flavor) unless @openstack_deployment.overcloud_block_storage_count > 0
      attr_param_hash = attr_param_hash.except(:overcloud_object_storage_flavor) unless @openstack_deployment.overcloud_object_storage_count > 0

      attr_param_hash.each do |attr_name, param_name|
        attr_value = @openstack_deployment.send(attr_name)
        param_value = plan[param_name].try(:[], 'Default')
        errors[attr_name] = [_("Openstack #{param_name} was not properly synchronized.  Expected: #{attr_value} but got #{param_value}")] unless attr_value == param_value
      end

      ['CloudName', 'SSLRootCertificate', 'SSLCertificate', 'SSLKey'].each do |param_name|
        attr_value = ssl_params[param_name]
        param_value = plan[param_name].try(:[], 'Default')
        if attr_value.nil?
          errors[param_name] = [_("SSL Certificates were not properly generated for the Openstack Overcloud Deployment. #{param_name} value is nil.")]
        elsif attr_value != param_value
          errors[param_name] = [_("Openstack #{param_name} was not properly synchronized.  Expected: #{attr_value} but got #{param_value}")]
        end
      end

      env_ceph_external_setting = get_env_ceph_external_setting
      unless env_ceph_external_setting == @openstack_deployment.external_ceph_storage
        error_string = "Openstack environments/puppet-ceph-external.yaml was not properly synchronized.  "\
                       "Expected: #{@openstack_deployment.external_ceph_storage} but got #{env_ceph_external_setting}"
        errors['external_ceph_storage'] = [_(error_string)]
      end

      errors
    end

    def get_env_ceph_external_setting
      envs = undercloud_handle.get_plan_environments('overcloud')
      environment_groups = envs.find { |topic| topic[1]['title'] == 'Storage' }[1].try(:[], 'environment_groups')
      return nil unless environment_groups
      environments = environment_groups.find { |g| g['title'] == 'Externally managed Ceph' }.try(:[], 'environments')
      environments.try(:[], 0).try(:[], 'enabled')
    end

    def openstack_deployment_params
      params.fetch(:openstack_deployment, {}).permit(:undercloud_admin_password,
                                                   :undercloud_ip_address,
                                                   :undercloud_ssh_username,
                                                   :undercloud_ssh_password,
                                                   :overcloud_deployed,
                                                   :overcloud_ext_net_interface,
                                                   :overcloud_private_net,
                                                   :overcloud_float_net,
                                                   :overcloud_float_gateway,
                                                   :overcloud_password,
                                                   :overcloud_libvirt_type,
                                                   :overcloud_node_count,
                                                   :overcloud_compute_flavor,
                                                   :overcloud_compute_count,
                                                   :overcloud_controller_flavor,
                                                   :overcloud_controller_count,
                                                   :overcloud_ceph_storage_flavor,
                                                   :overcloud_ceph_storage_count,
                                                   :overcloud_block_storage_flavor,
                                                   :overcloud_block_storage_count,
                                                   :overcloud_object_storage_flavor,
                                                   :overcloud_object_storage_count,
                                                   :undercloud_hostname,
                                                   :overcloud_hostname,
                                                   :external_ceph_storage,
                                                   :ceph_ext_mon_host,
                                                   :ceph_cluster_fsid,
                                                   :ceph_client_username,
                                                   :ceph_client_key,
                                                   :nova_rdb_pool_name,
                                                   :cinder_rdb_pool_name,
                                                   :glance_rdb_pool_name)
    end
  end
end

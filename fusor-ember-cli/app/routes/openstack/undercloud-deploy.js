import Ember from 'ember';

export default Ember.Route.extend({
  // model() {
  //   return this.modelFor('openstack');
  // },

  setupController(controller, model) {
    controller.set('model', model);
    controller.set('showAlertMessage', false);
  },

  deactivate() {
    return this.send('saveDeployment', null);
  }

});

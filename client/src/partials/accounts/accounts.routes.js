
angular.module('bhima.routes')
  .config(['$stateProvider', function ($stateProvider) { 
    
    $stateProvider
      .state('accounts', {
        abstract : true,
        url : '/accounts',
        controller: 'AccountsController as AccountsCtrl',
        templateUrl: 'partials/accounts/accounts.html'
      })
    
      .state('accounts.create', {
        url : '/create',
        params : {
          parentId : { squash : true, value : null }
        },
        onEnter :['$state', '$uibModal', accountsModal] 
      })
      .state('accounts.list', {
        url : '/:id',
        params : { 
          id : { squash : true, value : null }
        }
      })
    
      .state('accounts.edit', { 
        url : '/:id/edit',
        params : { 
          id : { squash : true, value : null }
        },
        onEnter :['$state', '$uibModal', accountsModal]
      })
  }]);

function accountsModal($state, $modal) { 
  var instance = $modal.open({
              keyboard : false,
              backdrop : 'static',
              templateUrl: 'partials/accounts/edit/accounts.edit.modal.html',
              controller: 'AccountEditController as AccountEditCtrl'
            })
            
          instance.result.then(function (result) { 
            // clean up action
          });
}

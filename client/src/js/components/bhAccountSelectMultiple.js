angular.module('bhima.components')
  .component('bhAccountSelectMultiple', {
    templateUrl : 'modules/templates/bhAccountSelectMultiple.tmpl.html',
    controller  : AccountSelectController,
    transclude  : true,
    bindings    : {
      accountIds       : '<',
      onSelectCallback : '&',
      onChange : '&',
      disable          : '<?',
      required         : '<?',
      accountTypeId    : '<?',
      label            : '@?',
      name             : '@?',
      excludeTitleAccounts : '@?',
      validationTrigger :  '<?',
    },
  });

AccountSelectController.$inject = [
  'AccountService', 'appcache', '$timeout', 'bhConstants', '$scope',
];

/**
 * Account selection component
 */
function AccountSelectController(Accounts, AppCache, $timeout, bhConstants, $scope) {
  const $ctrl = this;
  const hasCachedAccounts = false;
  const cache = new AppCache('bhAccountSelectMultiple');

  // fired at the beginning of the account select
  $ctrl.$onInit = function $onInit() {

    // cache the title account ID for convenience
    $ctrl.TITLE_ACCOUNT_ID = bhConstants.accounts.TITLE;

    // translated label for the form input
    $ctrl.label = $ctrl.label || 'FORM.LABELS.ACCOUNT';

    // used to disable title accounts in the select list
    $ctrl.disableTitleAccounts = angular.isDefined($ctrl.disableTitleAccounts)
      ? $ctrl.disableTitleAccounts : true;

    // default for form name
    $ctrl.name = $ctrl.name || 'AccountForm';

    // parent form submitted
    $ctrl.validationTrigger = $ctrl.validationTrigger || false;

    if (!angular.isDefined($ctrl.required)) {
      $ctrl.required = true;
    }

    $ctrl.excludeTitleAccounts = angular.isDefined($ctrl.excludeTitleAccounts)
      ? $ctrl.excludeTitleAccounts : true;

    // load accounts
    loadAccounts();

    // alias the name as AccountForm
    $timeout(aliasComponentForm);
  };

  // this makes the HTML much more readable by reference AccountForm instead of the name
  function aliasComponentForm() {
    $scope.AccountForm = $scope[$ctrl.name];
  }

  /**
   * Checks if there the accounts have been updated recently and loads
   * the cached versions if so.  Otherwise, it fetches the accounts from
   * the server and caches them locally.
   */
  function loadAccounts() {
    if (hasCachedAccounts) {
      loadCachedAccounts();
    } else {
      loadHttpAccounts();
    }
  }

  // simply reads the accounts out of localstorage
  function loadCachedAccounts() {
    $ctrl.accounts = cache.accounts;
  }

  // loads accounts from the server
  function loadHttpAccounts() {
    const detail = $ctrl.accountTypeId;
    const detailed = detail ? 1 : 0;
    const params = { detailed };

    if ($ctrl.accountTypeId) {
      params.type_id = $ctrl.accountTypeId
        .split(',')
        .map(num => parseInt(num, 10));
    }

    // NOTE: this will hide all "hidden" accounts
    params.hidden = 0;

    // load accounts
    Accounts.read(null, params)
      .then(elements => {
        // bind the accounts to the controller
        let accounts = Accounts.order(elements);

        if ($ctrl.excludeTitleAccounts) {
          accounts = Accounts.filterTitleAccounts(accounts);
        }

        $ctrl.accounts = accounts;

        // writes the accounts into localstorage
        // cacheAccounts($ctrl.accounts);

        // set the timeout for removing cached accounts
        // $timeout(removeCachedAccounts, CACHE_TIMEOUT);
      });
  }

  // write the accounts to localstorage
  /*
  function cacheAccounts(accounts) {
    hasCachedAccounts = true;
    cache.accounts = accounts;
  }

  */
  // fires the onSelectCallback bound to the component boundary
  $ctrl.onSelect = function onSelect($item) {
    $ctrl.onSelectCallback({ account : $item });

    // alias the AccountForm name so that we can find it via filterFormElements
    $scope[$ctrl.name].$bhValue = $item.id;
  };

  // fires the onChange bound to the component boundary
  $ctrl.handleChange = ($model) => {
    $ctrl.onChange({ id : $model });
  };

  /*
  // removes the accounts from localstorage
  function removeCachedAccounts() {
    hasCachedAccounts = false;
    delete cache.accounts;
  }
  */
}

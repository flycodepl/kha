angular.module('Kha').controller({
  LoginController: function ($scope, $http, authService) {
    $scope.urgent = false;
    $scope.login = function() {
      $http.post('user/login', {email: $scope.email, password: $scope.password}).success(function(data) {
        if (data.result === true) {
          $scope.session = data.session;
        }
        authService.loginConfirmed();
      }).error(function() {
        $scope.session = null;
        alert('Login fail!');
      });
    };
    $scope.logout = function() {
      $http.post('/user/logout', {}).success(function() {
        $scope.session = null;
      });
    };
    $http.get('/user/session').success(function(data) {
      if (data.result === true) {
        $scope.session = data.session;
      };
    });
    $scope.$on('event:auth-loginRequired', function() {
      $scope.urgent = true; //GP: it does not handle the case when user is logged in, but does not have rights to perform an action
    });
    $scope.$on('event:auth-loginConfirmed', function() {
      $scope.urgent = false;
    });
  }
});

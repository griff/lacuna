(function($) {

var loaded = false,
    auth = {},
    at = $.cookie('token'),
    latest_username=null;

if(at) {
  auth.access_token = at;
}

$.ajaxPrefilter( function( options, originalOptions, jqXHR ) {
  if(auth.access_token && !options.ignoreOAuthToken) {
    if(!options.headers) {
      options.headers = {};
    }
    options.headers.Authorization =  'Bearer '+auth.access_token;
  }
});

$(window).bind('loadedtoken', function(event, access_token, expires_in){
    $.ajaxSetup({
      statusCode: {
        401: function(xhr) {
          auth.access_token = null;
          $(window).trigger('login');
        }
      }
    });
    auth.access_token = access_token;
    if(auth.refreshTimer)
      clearTimeout(auth.refreshTimer)
    if(expires_in) {
      //console.log('Setting expires timer to', expires_in);
      auth.refreshTimer = setTimeout(function(){$(window).trigger('refreshtoken', access_token);},(expires_in-30)*1000);
    } else {
      $.getJSON($(window).data('api').token_info, function(data) {
        //console.log('Setting expires timer to', data.expires_in);
        auth.refreshTimer = setTimeout(function(){$(window).trigger('refreshtoken', access_token);},(data.expires_in-30)*1000);
      });
    }
    $(window).trigger('authenticated');
});

$(window).bind('refreshtoken', function(event, access_token) {
  $.ajax({
    url:$(window).data('api').auth,
    ignoreOAuthToken:true,
    type:'POST',
    dataType:'json',
    data: {client_id:1, grant_type:'refresh_token', refresh_token:access_token},
    success: function(data, xhr) {
      var expires = new Date();
      expires.setTime(expires.getTime() + data.expires_in*1000);
      $.cookie('token', data.access_token, { expires: expires, path: '/'});
      $(window).trigger('loadedtoken', data.access_token, data.expires_in);
    },
    error: function() {
      $(window).trigger('login');
    }
  });
});

$.ajax({
  url:'/api',
  type:'GET',
  dataType:'json',
  ignoreOAuthToken:true,
  success:function(data) {
    $(window).data('api', data);
    if(loaded) {
      $.fancybox.hideActivity();
      if(auth.access_token) {
        $(window).trigger('loadedtoken', auth.access_token);
      } else {
        $(window).trigger('login');
      }
    }
  }
});

$(function() {
  $.fancybox.showActivity();
  
  // Show overlay box with result on ajax errors
  $(document.body).ajaxError(function(event, xhr, options, exception) {
    //console.log("Ajax error ", event, xhr, " ", xhr.status, " ", xhr.readyState, " ", exception);
    //var content = $('<div>'+exception+'</div>');
    if( xhr.readyState === 4 && xhr.status >= 500 && xhr.responseText !== "" ) {
      if(xhr.getResponseHeader( "content-type" ) === "text/plain") {
        var c = $('<pre></pre>').text(xhr.responseText);
        $.fancybox({content:c[0]});
      } else {
        $.fancybox(xhr.responseText);
      }
    }
  });
      
  loaded = true;
  if($(window).data('api')) {
    $.fancybox.hideActivity();
    if(auth.access_token) {
      $(window).trigger('loadedtoken', auth.access_token, $(window).data('api').token_expires_in);
    } else {
      $(window).trigger('login');
    }
    //console.log('Trigger start login');
  }
  
});

$(window).bind('login', function(e) {
  var login = $('#login');
  login.dialog({
    modal:true,
    allowClose:false,
    buttonOnEnter:':first',
    buttons:{
      'Log ind': function() {
        $.fancybox.showActivity();
        var self=$(this),
            username = $('#username', self).val(),
            password = $('#password', self).val();
        $.ajax({
          url:$(window).data('api').auth,
          type:'POST',
          dataType:'json',
          data: {client_id:1, grant_type:'password', username:username, password:password},
          headers: {},
          success: function(data, xhr) {
            $.fancybox.hideActivity();
            var expires = new Date();
            expires.setTime(expires.getTime() + data.expires_in*1000);
            $.cookie('token', data.access_token, { expires: expires, path: '/'});
            $(window).trigger('loadedtoken', data.access_token, data.expires_in);
            self.dialog('close');
          },
          statusCode: {
            400: function(xhr) {
              $.fancybox.hideActivity();
              data = $.parseJSON(xhr.responseText);
              message = data.error;
              if(data.error_description) {
                message = data.error_description;
              }
              $('.messages strong', login).text(message).parent().show();
            },
            401: function(xhr) {
              $.fancybox.hideActivity();
              data = $.parseJSON(xhr.responseText);
              message = data.error;
              if(data.error_description) {
                message = data.error_description;
              }
              $('.messages strong', login).text(message).parent().show();
            }
          }
        });
      }
    },

  });
});

})(jQuery);
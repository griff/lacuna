(function($) {

$(function() {
  $(document).bind('keydown', 'b', function(event) {
    event.preventDefault();
    $('#user-add').click();
  });
      
  $('#user-add').button({icons:{primary:'ui-icon-plusthick'}}).click(function(event) {
    event.preventDefault();
    $(window).trigger('usercreate', 'Lav bruger');
  });
    
  $(window).bind('usercreate', function(event, title, old) {
    var user = $('#user'),
        pw1 = $('#user_password'),
        pw2 = $('#user_password_repeat'),
        user_name = $('#user_name'),
        user_gecos = $('#user_gecos');
    $('.messages', user).hide();
    if(old) {
      user_name.val(old.name).attr('readonly', 'readonly');
      user_gecos.val(old.gecos);
    } else {
      user_name.val('').removeAttr('readonly');
      user_gecos.val('');
    }
    pw1.val('');
    pw2.val('');

    user.dialog({
      title:title,
      buttonOnEnter:':first',
      modal:true,
      buttons:{
        'OK': function() {
          //console.log('Old data', old, old && old.restore);
          if(pw1.val() !== pw2.val()) {
            $('.messages strong', user).text('Kodeord er gentaget forkert').parent().show();
          } else {
            var data = {name:user_name.val(), gecos:user_gecos.val(), password:pw1.val()};
            if(old && old.restore) {
              data.restore = old.restore;
            }
            //console.log('Old data', old, old && old.restore);
            $.ajax({
              url:$(window).data('api').users,
              type:'POST',
              dataType:'json',
              data:data,
              success: function() {
                latest_username = user_name.val();
                user.dialog('close');
                $(window).trigger('usercreated', data);
              },
              error: function(xhr) {
                if(xhr.status !== 401 && xhr.getResponseHeader( "content-type" ) === 'application/json') {
                  var err = $.parseJSON(xhr.responseText),
                      message = err.error;
                  if(err.error_description) {
                    message = err.error_description;
                  }
                  $('.messages strong', user).text(message).parent().show();
                }
              }
            });
          }
        },
        'Fortryd': function() {
          user.dialog('close');
          $('table#users').focus();
        }
      }
    });
  });

  $('#users').delegate('span.delete', 'click', function(event) {
    var self = $(event.currentTarget),
        href = self.data('href');
    $.ajax({
      url:href,
      type:'DELETE',
      dataType:'json',
      success: function() {
        $(window).trigger('userdeleted'); 
      }
    });
  })

  $('#trash').delegate('span.restore', 'click', function(event) {
    var self = $(event.currentTarget),
        href = self.data('href');
    $.ajax({
      url:href,
      type:'GET',
      dataType:'json',
      success: function(data) {
        $(window).trigger('usercreate', ['Gendan bruger', {name:data.name, gecos:data.user.gecos, restore:data.url}]);
      }
    });
  });

  $('#trash').delegate('span.delete', 'click', function(event) {
    var self = $(event.currentTarget),
        href = self.data('href');
    $.ajax({
      url:href,
      type:'DELETE',
      dataType:'json',
      success: function() {
        $(window).trigger('trashreload');
      }
    });
  })
  

  $('#users').delegate('span.edit', 'click', function(event) {
  
    var self = $(event.currentTarget),
        href = self.data('href'),
        user = $('#user'),
        gecos = $('#user_gecos', user),
        pw1 = $('#user_password'),
        pw2 = $('#user_password_repeat'),
        user_name = $('#user_name', user);
    //console.log('Loading ', href);
    $.getJSON(href, function(data) {
      $('.messages', user).hide();
      user_name.val(data.name).attr('readonly', 'readonly');
      gecos.val(data.gecos);
      pw1.val('');
      pw2.val('');

      user.dialog({
        title:'Rediger bruger',
        buttonOnEnter:':first',
        modal:true,
        buttons:{
          'OK': function() {
            if(pw1.val() !== pw2.val()) {
              $('.messages strong', user).text('Kodeord er gentaget forkert').parent().show();
            }
            if(pw1.val() !== '') {
              data.password = pw1.val();
            }
            data.gecos = gecos.val();
            $.ajax({
              url:href,
              type:'PUT',
              dataType:'json',
              data:data,
              success: function() {
                latest_username = user_name.val();
                user.dialog('close');
                $(window).trigger('usermodified', data);
              },
              error: function(xhr) {
                if(xhr.status !== 401 && xhr.getResponseHeader( "content-type" ) === 'application/json') {
                  var err = $.parseJSON(xhr.responseText),
                      message = err.error;
                  if(err.error_description) {
                    message = err.error_description;
                  }
                  $('.messages strong', user).text(message).parent().show();
                }
              }
            });
          },
          'Fortryd': function() {
            user.dialog('close');
            $('table#users').focus();
          }
        }
      });
    });
  });
});

$(window).bind('usercreated', function(event, data) {
  if(data.restore) {
    $(window).trigger('trashreload');
  }
});

$(window).bind('usercreated usermodified', function() {
  $(window).trigger('usersreload');
  $('table#users').focus();
})

$(window).bind('userdeleted', function(e) {
  $(window).trigger('usersreload');
  $(window).trigger('trashreload');
});

$(window).bind('usersreload', function(e) {
  var users = $('table#users'),
      ejs = new EJS({url: 'ejs/users.ejs'});
  $('tbody.empty', users).hide();
  $('tbody.loading', users).show();

  $.getJSON($(window).data('api').users, function(data) {
    var oldbody = $('tbody.data', users),
        newbody = $(ejs.render(data));
    $('tbody.loading', users).hide();
    if(data.length === 0) {
      $('tbody.empty', users).show();
    }
    oldbody.remove();
    newbody.appendTo(users);
  });
});

$(window).bind('trashreload', function(e) {
  var users = $('table#trash'),
      ejs = new EJS({url: 'ejs/trash.ejs'});
  $('tbody.empty', users).hide();
  $('tbody.loading', users).show();

  $.getJSON($(window).data('api').trash, function(data) {
    var oldbody = $('tbody.data', users),
        newbody = $(ejs.render(data));
    $('tbody.loading', users).hide();
    if(data.length === 0) {
      $('tbody.empty', users).show();
    }
    oldbody.remove();
    newbody.appendTo(users);
  });
});

})(jQuery);
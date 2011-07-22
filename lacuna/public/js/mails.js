(function($) {

$(function() {
  $(window).bind('keydown', 'a', function(event) {
    event.preventDefault();
    $('#alias-add').click();
  });
  
  $('#alias-add').button({icons:{primary:'ui-icon-plusthick'}}).click(function(event) {
    event.preventDefault();
    var alias = $('#alias'),
        alias_name = $('#alias_name'),
        alias_user = $('#alias_user');
    $('.messages', alias).hide();
    alias_name.val('');
    alias_user.val(latest_username);

    alias.dialog({
      buttonOnEnter:':first',
      modal:true,
      focus:function() {
        alias_user.focus();
        alias_user.select();
      },
      buttons:{
        'OK': function() {
          $.ajax({
            url:api.mail_aliases,
            type:'POST',
            dataType:'json',
            data:{name:alias_name.val(), user:alias_user.val()},
            success: function() {
              latest_username = alias_user.val();
              $(window).trigger('mailaliasessreload');
              alias.dialog('close');
              $('#mail_aliases').focus();
              
            },
            error: function(xhr) {
              if(xhr.status !== 401 && xhr.getResponseHeader( "content-type" ) === 'application/json') {
                var err = $.parseJSON(xhr.responseText),
                    message = err.error;
                if(err.error_description) {
                  message = err.error_description;
                }
                $('.messages strong', alias).text(message).parent().show();
              }
            }
          });
        },
        'Fortryd': function() {
          alias.dialog('close');
          $('#mail_aliases').focus();
        }
      }
    });
  });

  $('#mail_aliases').delegate('span.delete', 'click', function(event) {
    var self = $(event.currentTarget),
        href = self.data('href');
    $.ajax({
      url:href,
      type:'DELETE',
      dataType:'json',
      success: function(data2) {
        $(window).trigger('mailaliasessreload');
      }
    });
  })

  $('#mailqueue').delegate('span.delete', 'click', function(event) {
    var self = $(event.currentTarget),
        href = self.data('href');
    $.ajax({
      url:href,
      type:'DELETE',
      dataType:'json',
      success: function(data2) {
        $(window).trigger('mailsreload');
      }
    });
  })

});

$(window).bind('mailsreload', function(e) {
  var queue = $('table#mailqueue');
  $('tbody.empty', queue).hide();
  $('tbody.loading', queue).show();

  $.getJSON(api.mails, function(data) {
    var oldbody = $('tbody.data', queue),
        newbody = $('<tbody></tbody>').addClass('data');
        
    $.each( data, function( index, item ) {
      var html = '<tr><td rowspan="2" class="center">'+item.queue_time+'</td>'+
      '<td class="center">'+item.size+'</td><td>'+item.id+'</td><td>'+item.from+
      '</td><td>'+item.to+'</td><td class="center">'+(item.frozen===true ? 'ja' : 'nej')+'</td><td rowspan="2"><span class="delete" data-href="' + 
      item.url+'">Slet</span> <span class="delete" data-href="'+(item.frozen ? item.thaw_url + '">Thaw' : item.freeze_url + '">Freeze')+'</span></td></tr>' +
      '<tr><td colspan="5">'+item.log.join('<br>')+'</td></tr>';
      $(html).appendTo(newbody);
    });
    $('tbody.loading', queue).hide();
    if(data.length === 0) {
      $('tbody.empty', queue).show();
    }
    oldbody.remove();
    newbody.appendTo(queue);
  });
});

$(window).bind('userdeleted', function(e) {
  $(window).trigger('mailaliasessreload');
});

$(window).bind('mailaliasessreload', function(e) {
  var table = $('table#mail_aliases');
  $('tbody.empty', table).hide();
  $('tbody.loading', table).show();

  $.getJSON(api.mail_aliases, function(data) {
    var oldbody = $('tbody.data', table),
        newbody = $('<tbody></tbody>').addClass('data');
        
    $.each( data, function( index, item ) {
      var html = '<tr><td>'+item.name+'</td><td>'+item.user+
        '</td><td><span class="delete" data-href="' + item.url+'">Slet</span></td></tr>';
      $(html).appendTo(newbody);
    });
    $('tbody.loading', table).hide();
    if(data.length === 0) {
      $('tbody.empty', table).show();
    }
    oldbody.remove();
    newbody.appendTo(table);
  });
});


})(jQuery);
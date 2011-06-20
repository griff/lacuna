(function($) {
$.ui.dialog.prototype.options.buttonOnEnter = false;

var originalCreate = $.ui.dialog.prototype._create;
$.ui.dialog.prototype._create = function() {
    var self = this;
    originalCreate.apply(self, arguments);
    self.uiDialog.bind('keydown.dialog', function(event) {
        var buttonOnEnter = self.options.buttonOnEnter;
        if (buttonOnEnter && event.keyCode &&
            event.keyCode === $.ui.keyCode.ENTER &&
            event.target.tagName !== "TEXTAREA")
        {
            //console.log("Dialog enter", event.target);
            event.preventDefault();
            self.pressButton(buttonOnEnter, event);
        }
    });
};

$.ui.dialog.prototype.pressButton = function(button, event) {
    var self = this,
        options = self.options,
        buttons = options.buttons,
        ctrl = self.uiDialog.find('.ui-dialog-buttonpane button');
        
    if($.isPlainObject(buttons)) {
        var btn = buttons[button];
        if($.isFunction(btn)) {
            ctrl.filter(function() {
                return ($.fn.button ? $(this).button('label') : $(this).text()) === button;
            }).first().trigger('click', event);
            return;
        }
    }
    ctrl.filter(button).first().trigger('click', event);
};
}(jQuery));
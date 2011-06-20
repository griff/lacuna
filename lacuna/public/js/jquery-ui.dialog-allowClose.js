(function($) {
$.ui.dialog.prototype.options.allowClose = true;

var originalCreate = $.ui.dialog.prototype._create;
$.ui.dialog.prototype._create = function() {
    var self = this;
    originalCreate.apply(self, arguments);
    self.originalCloseOnEscape = null;
    self._adjustCloseable(self.options.allowClose);
};

var originalSetOption = $.ui.dialog.prototype._setOption;
$.ui.dialog.prototype._setOption = function(key, value) {
	var self = this;

	switch (key) {
	    case "allowClose":
	        self._adjustCloseable(value);
	        break;
	    case "closeOnEscape":
	        if(!self.options.allowClose)
	        {
	            self.originalCloseOnEscape = value;
	            return;
	        }
	}
    originalSetOption.apply(self, arguments);
};

$.ui.dialog.prototype._adjustCloseable = function(value) {
    var self = this,
	    options = self.options,
	    closeBtn = self.uiDialogTitlebarCloseText.parent();
	if(value)
	{
	    if(self.originalCloseOnEscape !== null)
	    {
            options.closeOnEscape = self.originalCloseOnEscape;
            self.originalCloseOnEscape = null;
	    }
    	closeBtn.show();
	}
	else
	{
	    if(self.originalCloseOnEscape === null)
	    {
            self.originalCloseOnEscape = options.closeOnEscape;
            options.closeOnEscape = false;
	    }
        closeBtn.hide();
	}
};
}(jQuery));
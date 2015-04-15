/**
*  jQuery lwDialog 轻量级的弹框插件
*/
 
(function ($) {
	$.fn.lwDialog = function (options) {
		var defaults = {
			width: 600, 
			height: 'auto', 
			title:'弹出信息',
			closeByEscape: true,
			closeByDocument: true,
			holderClass: '',
			overlayClass: '',
			onBlurContainer: '',
			openOnEvent: true,
			setEvent: 'click',
			onLoad: false,
			onUnload: false,
			template: '暂无内容',
			onPrepare:function(){ return true; },
			onOk:function(){ }
		};
		options = $.extend(defaults, options);
		return this.each(function() {
			var self = $(this),
				body = $('body'),
				maxWidth = options.width > 640 ? 640 : options.width,
				maxHeight = options.height > 350 ? 350 : options.height,
				template = typeof options.template === 'function' ? options.template(self) : options.template;
			    body.addClass('avgrund-ready');
			    body.append('<div class="avgrund-overlay ' + options.overlayClass + '"></div>');
			if (options.onBlurContainer !== '') {
				$(options.onBlurContainer).addClass('avgrund-blur');
			}
			function onDocumentKeyup (e) {
				if (options.closeByEscape) {
					if (e.keyCode === 27) {
						deactivate();
					}
				}
			}

			function onDocumentClick (e) {
				if (options.closeByDocument) {
					if ($(e.target).is('.avgrund-overlay,.avgrund-cancel, .avgrund-close')) {
						e.preventDefault();
						deactivate();
					}
				}
				if ($(e.target).is('.avgrund-cancel, .avgrund-close')) {
						e.preventDefault();
						deactivate();
				}
				if ($(e.target).is('.avgrund-ok')) {
						e.preventDefault();
						if(options.onOk()) deactivate();	
				}
			}
			function createPopinDom(){
				return ['<div class="avgrund-popin ' + options.holderClass + '">',
			              '<div class="avgrund-header">',
				          '<button type="button" class="avgrund-close">×</button>',
				          '<h3>'+ options.title +'</h3>',
                        '</div>',
			            '<div class="avgrund-content">'+ template + '</div>',
					    '<div class="avgrund-footer">',
					    '<button class="avgrund-ok">确定</button>',
				        '<button class="avgrund-cancel">取消</button>', 				    
					    '</div>',
			            '</div>'].join('');
			}
			function activate () {
				if (typeof options.onLoad === 'function') {
					options.onLoad(self);
				}
				setTimeout(function() {
					body.addClass('avgrund-active');
				}, 100);
				body.append(createPopinDom());
				$('.avgrund-popin').css({
					'width': maxWidth + 'px',
					'height': maxHeight + 'px',
					'margin-left': '-' + (maxWidth / 2 + 10) + 'px',
					'margin-top': '-' + (maxHeight / 2 + 10) + 'px'
				});
				body.bind('keyup', onDocumentKeyup);
				body.bind('click', onDocumentClick);
			}
			function deactivate () {
				body.unbind('keyup', onDocumentKeyup);
				body.unbind('click', onDocumentClick);
				body.removeClass('avgrund-active');
				setTimeout(function() {
					$('.avgrund-popin').remove();
				}, 500);
				if (typeof options.onUnload === 'function') {
					options.onUnload(self);
				}
			}
			if (options.openOnEvent) {
				self.bind(options.setEvent, function (e) {
					console.log(options.onPrepare);
					if(!options.onPrepare()) return false;
					e.stopPropagation();
					if ($(e.target).is('a')) {
						e.preventDefault();
					}
					activate();
				});
			} else {
				activate();
			}
		});
	};
})(jQuery);

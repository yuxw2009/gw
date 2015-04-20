/*
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
			includeOk:true,
			cancelText:'取消',
			onpreEvent:function(){}, 
			onLoad: false,
			onUnload: false,
			template: '暂无内容',
			onOk:function(){ },
			onClose:function() {}
		};
		options = $.extend(defaults, options);
		return this.each(function() {
			var self = $(this),
				body = $('body'),
				//maxWidth = options.width > 640 ? 640 : options.width,
				//maxHeight = options.height > 350 ? 350 : options.height,
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
						options.onClose();	
						deactivate();
				}
				if ($(e.target).is('.avgrund-ok')) {
						e.preventDefault();
						if(options.onOk()) deactivate();	
				}
			}

			function createPopinDom(){
				return ['<div style="display:none;" class="avgrund-popin ' + options.holderClass + '">',
			              '<div class="avgrund-header">',
				          '<button type="button" class="avgrund-close">×</button>',
				          '<h3>'+ options.title +'</h3>',
                        '</div>',
			            '<div class="avgrund-content"></div>',
					    '<div class="avgrund-footer">',
					    options.includeOk == true ?  '<button class="avgrund-ok">确定</button>' : '',
				        '<button class="avgrund-cancel">'+ options.cancelText +'</button>', 				    
					    '</div>',
			            '</div>'].join('');
			}

			function activate () {
				if (typeof options.onLoad === 'function') {
					options.onLoad(self);
				}
				setTimeout(function() {
					body.addClass('avgrund-active');
				}, 10);
				body.append(createPopinDom());
				body.find('.avgrund-content').css({
					'width': options.width + 'px',
					'height': options.height + 'px',
				}).html(template.show());

				$('.avgrund-popin').css({
					'display':'block',
					'left': ($(window).width() -(options.width + 46))/2, 
					'top': ($(window).height() -(options.height + 105))/2,
					'width': options.width + 46 + 'px',
					'height': options.height + 105 + 'px'
				});
				body.bind('keyup', onDocumentKeyup);
				body.bind('click', onDocumentClick);
			}

			function deactivate () {
				body.unbind('keyup', onDocumentKeyup);
				body.unbind('click', onDocumentClick);
				body.removeClass('avgrund-active');
				setTimeout(function() {
					$('.avgrund-popin').html('').remove();
				}, 500);
				if (typeof options.onUnload === 'function') {
					options.onUnload(self);
				}
			}
			if (options.openOnEvent) {
				self.bind(options.setEvent, function (e) {					
					e.stopPropagation();
					if ($(e.target).is('a')) {
						e.preventDefault();
					}
					activate();
					
					options.onpreEvent($(this));
				});
			} else {
				activate();
			}
		});
	};
})(jQuery);

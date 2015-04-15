/**
 * jQuery plugin for getting position of cursor in textarea

 * @license under GNU license
 * @author Bevis Zhao (i@bevis.me, http://bevis.me)
 */
$(function() {
	var calculator = {
		// key styles
		primaryStyles: ['fontFamily', 'fontSize', 'fontWeight', 'fontVariant', 'fontStyle',
			'paddingLeft', 'paddingTop', 'paddingBottom', 'paddingRight',
			'marginLeft', 'marginTop', 'marginBottom', 'marginRight',
			'borderLeftColor', 'borderTopColor', 'borderBottomColor', 'borderRightColor',
			'borderLeftStyle', 'borderTopStyle', 'borderBottomStyle', 'borderRightStyle',
			'borderLeftWidth', 'borderTopWidth', 'borderBottomWidth', 'borderRightWidth',
			'line-height', 'outline'],

		specificStyle: {
			'word-wrap': 'break-word',
			'overflow-x': 'hidden',
			'overflow-y': 'auto'
		},
		simulator : $('<div id="textarea_simulator"/>').css({
				position: 'absolute',
				top: 0,
				left: 0,
				visibility: 'hidden'
			}).appendTo(document.body),

		toHtml : function(text) {
			return text.replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g, '<br>')
				.split(' ').join('<span style="white-space:prev-wrap">&nbsp;</span>');
		},
		// calculate position
		getCaretPosition: function() {
			var cal = calculator, self = this, element = self[0], elementOffset = self.offset();
			//if ($.browser.msie) {
			//	element.focus();
		   //     var range = document.selection.createRange();

		    //    alert(range.boundingLeft)
		    //    alert(range.boundingTop)

		    //    $('#hskeywords').html(element.scrollTop);
			//    return {
			//        left: range.boundingLeft - elementOffset.left,
			//        top: parseInt(range.boundingTop) - elementOffset.top + element.scrollTop
			//			+ document.documentElement.scrollTop + parseInt(self.getComputedStyle("fontSize"))
			//    };
		   // }
			cal.simulator.empty();
			// clone primary styles to imitate textarea
			$.each(cal.primaryStyles, function(index, styleName) {            
				self.cloneStyle(cal.simulator, styleName);
			});

			// caculate width and height
			cal.simulator.css($.extend({
				'width': self.width(),
				'height': self.height()
			}, cal.specificStyle));

			var value = self.html(), cursorPosition = self.getCursorPosition();

			var beforeText = value.substring(0, cursorPosition),
				afterText = value.substring(cursorPosition);
				
			var before = $('<span class="before"/>').html(cal.toHtml(beforeText)),
				focus = $('<span class="focus"/>'),
				after = $('<span class="after"/>').html(cal.toHtml(afterText));
			cal.simulator.append(before).append(focus).append(after);	
			var focusOffset = focus.offset(), simulatorOffset = cal.simulator.offset();
			return {
				top: focusOffset.top - simulatorOffset.top - element.scrollTop
					// calculate and add the font height except Firefox
					+ ($.browser.mozilla ? 0 : parseInt(self.getComputedStyle("fontSize"))),
				left: focus[0].offsetLeft -  cal.simulator[0].offsetLeft - element.scrollLeft
			};
		}
	};

	$.fn.extend({
		getComputedStyle: function(styleName) {
			if (this.length == 0) return;
			var thiz = this[0];
			var result = this.css(styleName,'');
			result = result || ($.browser.msie ?
				thiz.currentStyle[styleName]:
				document.defaultView.getComputedStyle(thiz, null)[styleName]);
			return result;
		},
		// easy clone method

		cloneStyle: function(target, styleName) {

			var styleVal = this.getComputedStyle(styleName);

			if (!!styleVal) {
				$(target).css(styleName, styleVal);
			}
		},

		cloneAllStyle: function(target, style) {
			var thiz = this[0];
			for (var styleName in thiz.style) {
				var val = thiz.style[styleName];
				typeof val == 'string' || typeof val == 'number'
					? this.cloneStyle(target, styleName)
					: NaN;
			}
		},
		getCursorPosition : function() {
	        var thiz = this[0], result = 0;
		    var  rng, srng;
	        if (window.getSelection) {
	            sel = window.getSelection();
	            if (sel.getRangeAt && sel.rangeCount) {
	                range = sel.getRangeAt(0);
	            }
	            result = range['startOffset'];
	        } else if (document.selection) {
	            rng = document.body.createTextRange();
	            rng.moveToElementText(thiz);
	            srng = document.selection.createRange();
	            srng.setEndPoint("StartToStart", rng);
	            result = srng.text.length;
	        }
	        return result; 
	    },
		getCaretPosition: calculator.getCaretPosition
	});
});

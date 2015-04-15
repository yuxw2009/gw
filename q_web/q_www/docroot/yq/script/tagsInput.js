(function($) {
	var delimiter = new Array();
	var tags_callbacks = new Array();
	var getuuid = '';
	$.fn.doAutosize = function(o){
	    var minWidth = $(this).data('minwidth'),
	        maxWidth = $(this).data('maxwidth'),
	        val = '',
	        input = $(this),
	        testSubject = $('#'+$(this).data('tester_id'));
	    if (val === (val = input.val())) {return;}
	    // Enter new content into testSubject
	    var escaped = val.replace(/&/g, '&amp;').replace(/\s/g,' ').replace(/</g, '&lt;').replace(/>/g, '&gt;');
	    testSubject.html(escaped);
	    // Calculate new width + whether to change
	    var testerWidth = testSubject.width(),
	        newWidth = (testerWidth + o.comfortZone) >= minWidth ? testerWidth + o.comfortZone : minWidth,
	        currentWidth = input.width(),
	        isValidWidthChange = (newWidth < currentWidth && newWidth >= minWidth)
	                             || (newWidth > minWidth && newWidth < maxWidth);
	
	    // Animate width
	    if (isValidWidthChange) {
	        input.width(newWidth);
	    }


  };
  $.fn.resetAutosize = function(options){
    // alert(JSON.stringify(options));
    var minWidth =  $(this).data('minwidth') || options.minInputWidth || $(this).width(),
        maxWidth = $(this).data('maxwidth') || options.maxInputWidth || ($(this).closest('.tagsinput').width() - options.inputPadding),
        val = '',
        input = $(this),
        testSubject = $('<tester/>').css({
            position: 'absolute',
            top: -9999,
            left: -9999,
            width: 'auto',
            fontSize: input.css('fontSize'),
            fontFamily: input.css('fontFamily'),
            fontWeight: input.css('fontWeight'),
            letterSpacing: input.css('letterSpacing'),
            whiteSpace: 'nowrap'
        }),
        testerId = $(this).attr('id')+'_autosize_tester';
    if(! $('#'+testerId).length > 0){
      testSubject.attr('id', testerId);
      testSubject.appendTo('body');
    }

    input.data('minwidth', minWidth);
    input.data('maxwidth', maxWidth);
    input.data('tester_id', testerId);
    input.css('width', minWidth);
  };
  
	$.fn.addTag = function(value,options) {
			options = jQuery.extend({focus:false,callback:true},options);
			this.each(function() { 
				var id = $(this).attr('id');
				var tagslist = $(this).val().split(delimiter[id]);
				if (tagslist[0] == '') { 
					tagslist = new Array();
				}
				value = jQuery.trim(value);
				if (options.unique) {
					var skipTag = $(this).tagExist(value);
					if(skipTag == true) {
						$('#'+id+'_tag').val('');
    				}
				} else {
					var skipTag = false; 
				}
				if (value !='' && skipTag != true) { 
					var tel  = options.phone ? options.phone : value;
		            var name =   options.phone ? '[' + value + ']' : '[未知]' ; 
					var k = (options.type === 'email'? tel : tel + name); 
					if(options.type === 'email')  value = ( name === '[未知]' ||  name === '['+ tel +']' ? tel : tel + name) ; 
				
					$('<span>').addClass('tag').attr('data', k).append(
                        $('<span>').text(value).append('&nbsp;&nbsp;'),
                        $('<a>', {
                            href  : '#',
                            title : 'Removing tag',
                            text  : 'x'
                        })
                    ).click(function () {
                         return $('#' + id).removeTag(escape(value), escape(k) );
                    }).insertBefore('#' + id + '_addTag');

					tagslist.push(value);				
					$('#'+id+'_tag').val('');
					if (options.focus) {
						$('#'+id+'_tag').focus();
					} else {		
						$('#'+id+'_tag').blur();
					}
					$.fn.tagsInput.updateTagsField(this,value ,options.phone , tagslist, options.type);		
					if (options.callback && tags_callbacks[id] && tags_callbacks[id]['onAddTag']) {
						var f = tags_callbacks[id]['onAddTag'];
						f.call(this, value);
					}
					if(tags_callbacks[id] && tags_callbacks[id]['onChange'])
					{
						var i = tagslist.length;
						var f = tags_callbacks[id]['onChange'];
						f.call(this, $(this), tagslist[i-1]);
					}					
				}
			});		
			
			return false;
		};
		
	$.fn.removeTag = function(value, data) { 
			value = unescape(value);
			data = unescape(data);
			this.each(function() { 
				var id = $(this).attr('id');
				var old = $(this).val().split(delimiter[id]);
				var old_data= $(this).attr('data').split(delimiter[id]);				
				$('#'+id+'_tagsinput .tag').remove();
				var str = '', str2 ='';
				for (i=0; i< old.length; i++) { 
					if (old[i]!=value) { 
						str = str + delimiter[id] +old[i];
						str2 = str2 + delimiter[id] +old_data[i];
					}
				}
				$.fn.tagsInput.importTags(this, str, str2);
				if (tags_callbacks[id] && tags_callbacks[id]['onRemoveTag']) {
					var f = tags_callbacks[id]['onRemoveTag'];
					f.call(this, value);
				}
			});					
			return false;
		};
	
	$.fn.tagExist = function(val) {
		var id = $(this).attr('id');
		var tagslist = $(this).val().split(delimiter[id]);
		return (jQuery.inArray(val, tagslist) >= 0); //true when tag exists, false when not
	};
	
	// clear all existing tags and import new ones from a string
	$.fn.importTags = function(str) {
        id = $(this).attr('id');
		$('#'+id+'_tagsinput .tag').remove();
		$.fn.tagsInput.importTags(this,str);
	}
		
	$.fn.tagsInput = function(options) { 
    var settings = jQuery.extend({
      interactive:true,
      defaultText:'add a tag',
      minChars:0,
      width:'100%',
      height:'30px',
      autocomplete: {selectFirst: false },
      'hide':true,
      'delimiter':',',
      'unique':true,
	  'getuuid': 'no',
	  'type': '',
      removeWithBackspace:true,
      placeholderColor:'#666666',
      autosize: true,
      comfortZone: 20,
      inputPadding: 6*2
    },options);
        $(this).attr('data','')
		this.each(function() { 
			if (settings.hide) { 
				$(this).hide();				
			}
			var id = $(this).attr('id');
			if (!id || delimiter[$(this).attr('id')]) {
				id = $(this).attr('id', 'tags' + new Date().getTime()).attr('id');
			}
			
			var data = jQuery.extend({
				pid:id,
				real_input: '#'+id,
				holder: '#'+id+'_tagsinput',
				input_wrapper: '#'+id+'_addTag',
				fake_input: '#'+id+'_tag'
			},settings);
			delimiter[id] = data.delimiter;	
			if (settings.onAddTag || settings.onRemoveTag || settings.onChange) {
				tags_callbacks[id] = new Array();
				tags_callbacks[id]['onAddTag'] = settings.onAddTag;
				tags_callbacks[id]['onRemoveTag'] = settings.onRemoveTag;
				tags_callbacks[id]['onChange'] = settings.onChange;
			}
	
			var markup = '<div id="'+id+'_tagsinput" class="tagsinput"><div id="'+id+'_addTag" class="addTag"><div class="seatips"> </div>';
			
			
			if (settings.interactive) {
				markup = markup + '<input id="'+id+'_tag" value="" data-default="'+settings.defaultText+'" />';
			}
			
			markup = markup + '</div><div class="tags_clear"></div></div>';
			
			$(markup).insertAfter(this);
			$(data.holder).css('width',settings.width);
			$(data.holder).css('min-height',settings.height);
		//	$(data.holder).css('max-height',clientHeight/2-100);
			$(data.holder).css('height','100%');
	
			if ($(data.real_input).val()!='') { 
				//$.fn.tagsInput.importTags($(data.real_input),$(data.real_input).val());
			}		
			if (settings.interactive) { 
				$(data.fake_input).val($(data.fake_input).attr('data-default'));
				$(data.fake_input).css('color',settings.placeholderColor);
		        $(data.fake_input).resetAutosize(settings);
		
				$(data.holder).bind('click',data,function(event) {
					$(event.data.fake_input).focus();
				});
			
				$(data.fake_input).bind('focus',data,function(event) {
					if ($(event.data.fake_input).val()==$(event.data.fake_input).attr('data-default')) { 
						$(event.data.fake_input).val('');
					}
					$(event.data.fake_input).css('color','#000000');		
				});
						
				if (settings.autocomplete_url != undefined) {
					autocomplete_options = {source: settings.autocomplete_url};
					for (attrname in settings.autocomplete) { 
						autocomplete_options[attrname] = settings.autocomplete[attrname]; 
					}
				
					if (jQuery.Autocompleter !== undefined) {
						$(data.fake_input).autocomplete(settings.autocomplete_url, settings.autocomplete);
						$(data.fake_input).bind('result',data,function(event,data,formatted) {
							if (data) {				
								$('#'+id).addTag(data[0] + "",{focus:true,unique:(settings.unique), type:(settings.type)});
							}
					  	});
					} else if (jQuery.ui.autocomplete !== undefined) {
						$(data.fake_input).autocomplete(autocomplete_options);
						$(data.fake_input).bind('autocompleteselect',data,function(event,ui) {
							$(event.data.real_input).addTag(ui.item.value,{focus:true,unique:(settings.unique), type:(settings.type)});
							return false;
						});
					}
				} else {
						// if a user tabs out of the field, create a new tag
						// this is only available if autocomplete is not used.
						$(data.fake_input).unbind('blur').bind('blur',data,function(event) {	
							var d = $(this).attr('data-default');
							var getphone = function(elem){
								var nameS = elem.indexOf('['), nameE = elem.indexOf(']');
                                var phoneStr = nameS < 0 ? elem : elem.substring(0, nameS);
			                    var nameStr , phone ;
								if(nameS < 0 || nameE < 0 || nameS >= nameE) {
									phone = correctPhoneNumber(elem);
								  if(settings.type === ''){
		                    	     !isPhoneNum(phone) ?  nameStr = '' :( nameStr = phoneStr ) ;
								  }else{
								     var reg = /^([a-zA-Z0-9_.-])+@([a-zA-Z0-9_-])+((\.[a-zA-Z0-9_.-]{2,3}){1,2})$/;
								     !reg.test(phone) ?  nameStr = '' :( nameStr = phoneStr ) ;
								  }
								}else{						
									nameStr = elem.substring(nameS + 1, nameE);				
								} 
								return { "phone": phoneStr, "name": nameStr };
							 }
				     
							if ($(event.data.fake_input).val()!='' && $(event.data.fake_input).val()!=d) {
								if( (event.data.minChars <= $(event.data.fake_input).val().length) && (!event.data.maxChars || (event.data.maxChars >= $(event.data.fake_input).val().length))){	
			                        var val = $(event.data.fake_input).val();
			                        var addTagFun = function(value){
			                          var name = getphone(value).name;
									  var phone = getphone(value).phone;
		                              var sb_name ;
				                      var str;
				                    //  console.log(name)
				                   //   console.log(phone)
		                              if('' == name) return false;
		                              if(name === '00000') name = phone;
									  $(event.data.real_input).addTag(name, {focus:true,unique:(settings.unique), 'phone': phone , type:(settings.type)});                 	
			                        }                   
								    if(val.indexOf(';') < 0){ 
								    	addTagFun(val);								    
								    }else{
								     str= val.split(';');	
								     for(var i=0 ; i< str.length; i++){
								       addTagFun(str[i]);
								     }
								   }
								}
							} else {		
							    $(event.data.fake_input).val($(event.data.fake_input).attr('data-default'));					
								$(event.data.fake_input).css('color',settings.placeholderColor);
							}
							return false;
						});
				
				}
				// if user types a comma, create a new tag
				
				$(data.fake_input).bind('keypress',data,function(event) {
					if (event.which==event.data.delimiter.charCodeAt(0)) {
					    event.preventDefault();
						if( (event.data.minChars <= $(event.data.fake_input).val().length) && (!event.data.maxChars || (event.data.maxChars >= $(event.data.fake_input).val().length)) )
							$(event.data.real_input).addTag($(event.data.fake_input).val(),{focus:true,unique:(settings.unique), type:(settings.type)});
					  	$(event.data.fake_input).resetAutosize(settings);
						return false;
					} else if (event.data.autosize) {
			            $(event.data.fake_input).doAutosize(settings);
            
          			}
				});
				
				//Delete last tag on backspace
				data.removeWithBackspace && $(data.fake_input).bind('keydown', function(event)
				{
					if(event.keyCode == 8 && $(this).val() == '')
					{
						 event.preventDefault();
						 var last_tag =  $(this).closest('.tagsinput').find('.tag:last').text();
						 var last_tag_data =  $(this).closest('.tagsinput').find('.tag:last').attr('data');
						 var id = $(this).attr('id').replace(/_tag$/, '');
						 last_tag = last_tag.replace(/[\s]+x$/, '');
						 last_tag_data = last_tag_data.replace(/[\s]+x$/, '');
						 $('#' + id).removeTag(escape(last_tag), escape(last_tag_data));
						 $(this).trigger('focus');
					}
				});
				$(data.fake_input).blur();				
				//Removes the not_valid class when user changes the value of the fake input
				if(data.unique) {
				    $(data.fake_input).keydown(function(event){
				        if(event.keyCode == 8 || String.fromCharCode(event.which).match(/\w+|[áéíóúÁÉÍÓÚñÑ,/]+/)) {
				            $(this).removeClass('not_valid');
				        }
				    });
				}
			} // if settings.interactive
		});
			
		return this;
	};
	$.fn.tagsInput.updateTagsField = function(obj,value, phone, tagslist) { 
		var id = $(obj).attr('id');
	    var tel  = phone ? phone : value;
		var name =   phone ? '[' + value + ']' : '[未知]' ; 
		var k =  (id === 'sendsms_input' && name.indexOf('@') !==1 ? tel + name : tel);
		var target = $('#'+ id +'_tagsinput');	
		$(obj).attr('data') === '' ?  $(obj).attr('data', k) : $(obj).attr('data', $(obj).attr('data')+ ';'  + k);	
        var max_height = parseInt(target.css('max-height'));
	    var con_box = parseInt(target.height());
		$(obj).val(tagslist.join(delimiter[id]));
	};
	$.fn.tagsInput.importTags = function(obj,val, val2) {			
		$(obj).val('');
		$(obj).attr('data','');
		var id = $(obj).attr('id');	
		var tags =  val.split(delimiter[id]);
		var tags2 = val2.split(delimiter[id]);		
		for (i=0; i<tags.length; i++) { 
	  	    var nameS = tags2[i].indexOf('['), nameE = tags2[i].indexOf(']');
            var phoneStr = nameS < 0 ? tags2[i] : tags2[i].substring(0, nameS);
			$(obj).addTag(tags[i],{focus:false,callback:false,'phone': phoneStr});
		}
		if(tags_callbacks[id] && tags_callbacks[id]['onChange'])
		{
			var f = tags_callbacks[id]['onChange'];
			f.call(obj, obj, tags[i]);
		}

	};
       
})(jQuery);

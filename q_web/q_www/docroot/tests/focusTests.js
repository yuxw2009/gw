module("focusTests");
/**/
test( "Init focus data", function() {
	var focus = new Focus();
		focus.init([]);
	deepEqual(focus.getExistingTagList(), []);
	deepEqual(focus.getTagsStatistics(), {'allFocuses':0, 'untagedFocuses':0});

		focus.init([{'type':'topics', 'tags':['aaa', 'bbb'], 'content':{'entity_id':'23'}}]);
	deepEqual(focus.getExistingTagList(), ['aaa', 'bbb']);
	deepEqual(focus.getTagsStatistics(), {'allFocuses':1, 'untagedFocuses':0, 'aaa':1, 'bbb':1});
	deepEqual(focus.getMsgsWithTag('aaa'), [{'type':'topics', 'msgid':'23'}]);
	deepEqual(focus.getMsgsWithTag('bbb'), [{'type':'topics', 'msgid':'23'}]);
});

test( "Set and cancel focus", function() {
	var focus = new Focus();
		focus.init([]);

	ok(!focus.isMsgIn('topics', '23'));
		focus.setFocus('topics', '23', ['aaa', 'bbb']);
	ok(focus.isMsgIn('topics', '23'));
	deepEqual(focus.getExistingTagList(), ['aaa', 'bbb']);
	deepEqual(focus.getTagsStatistics(), {'allFocuses':1, 'untagedFocuses':0, 'aaa':1, 'bbb':1});
    deepEqual(focus.getTags('topics', '23'), ['aaa', 'bbb']);
    deepEqual(focus.getMsgsWithTag('aaa'), [{'type':'topics', 'msgid':'23'}]);
	deepEqual(focus.getMsgsWithTag('bbb'), [{'type':'topics', 'msgid':'23'}]);

    	focus.setFocus('tasks', '141', ['bbb', 'ccc']);
    ok(focus.isMsgIn('tasks', '141'));
    deepEqual(focus.getExistingTagList(), ['aaa', 'bbb', 'ccc']);
	deepEqual(focus.getTagsStatistics(), {'allFocuses':2, 'untagedFocuses':0, 'aaa':1, 'bbb':2, 'ccc':1});
    deepEqual(focus.getTags('topics', '23'), ['aaa', 'bbb']);
    deepEqual(focus.getTags('tasks', '141'), ['bbb', 'ccc']);
    deepEqual(focus.getMsgsWithTag('aaa'), [{'type':'topics', 'msgid':'23'}]);
	deepEqual(focus.getMsgsWithTag('bbb'), [{'type':'topics', 'msgid':'23'}, {'type':'tasks', 'msgid':'141'}]);
	deepEqual(focus.getMsgsWithTag('ccc'), [{'type':'tasks', 'msgid':'141'}]);

    	focus.cancelFocus('tasks', '141');
    ok(focus.isMsgIn('topics', '23'));
    ok(!focus.isMsgIn('tasks', '141'));
	deepEqual(focus.getExistingTagList(), ['aaa', 'bbb']);
	deepEqual(focus.getTagsStatistics(), {'allFocuses':1, 'untagedFocuses':0, 'aaa':1, 'bbb':1});
	deepEqual(focus.getMsgsWithTag('aaa'), [{'type':'topics', 'msgid':'23'}]);
	deepEqual(focus.getMsgsWithTag('bbb'), [{'type':'topics', 'msgid':'23'}]);
});

test( "Modify tags of a msg", function() {
	var focus = new Focus();
		focus.init([]);

	focus.setFocus('topics', '23', ['aaa', 'bbb']);
    focus.setFocus('tasks', '141', ['bbb', 'ccc']);

    	focus.modifyTags('topics', '23', ['aaa','bbb'], ['bbb','eee']);
    deepEqual(focus.getExistingTagList(), ['bbb', 'ccc', 'eee']);
	deepEqual(focus.getTagsStatistics(), {'allFocuses':2, 'untagedFocuses':0, 'eee':1, 'bbb':2, 'ccc':1});
    deepEqual(focus.getTags('topics', '23'), ['bbb', 'eee']);
    deepEqual(focus.getTags('tasks', '141'), ['bbb', 'ccc']);
    deepEqual(focus.getMsgsWithTag('eee'), [{'type':'topics', 'msgid':'23'}]);
	deepEqual(focus.getMsgsWithTag('bbb'), [{'type':'tasks', 'msgid':'141'}, {'type':'topics', 'msgid':'23'}]);
	deepEqual(focus.getMsgsWithTag('ccc'), [{'type':'tasks', 'msgid':'141'}]);
});

test( "Batch modify tag", function() {
	var focus = new Focus();
		focus.init([]);

		focus.setFocus('topics', '23', ['aaa', 'bbb']);
    	focus.setFocus('tasks', '141', ['bbb', 'ccc']);

    	focus.batchModifyTag('bbb', 'ddd');
    deepEqual(focus.getExistingTagList(), ['aaa', 'ccc', 'ddd']);
	deepEqual(focus.getTagsStatistics(), {'allFocuses':2, 'untagedFocuses':0, 'aaa':1, 'ddd':2, 'ccc':1});
    deepEqual(focus.getTags('topics', '23'), ['aaa', 'ddd']);
    deepEqual(focus.getTags('tasks', '141'), ['ddd', 'ccc']);
    deepEqual(focus.getMsgsWithTag('aaa'), [{'type':'topics', 'msgid':'23'}]);
	deepEqual(focus.getMsgsWithTag('ddd'), [{'type':'topics', 'msgid':'23'}, {'type':'tasks', 'msgid':'141'}]);
	deepEqual(focus.getMsgsWithTag('ccc'), [{'type':'tasks', 'msgid':'141'}]);
});
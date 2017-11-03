//
//  TYPEID_View.m
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_TextBox_UIView.h"

#import "doInvokeResult.h"
#import "doIPage.h"
#import "doIScriptEngine.h"
#import "doUIModuleHelper.h"
#import "doScriptEngineHelper.h"
#import "doTextHelper.h"
#import "doIPage.h"
#import "doDefines.h"
#import "doInvokeResult.h"
#import "doJsonHelper.h"
#import "doIScrollView.h"

static NSString *didBeginEdit = @"DODidBeginEditNotification";
static NSString *keyboardShow = @"DOKeyboardShowNotification";
static NSString *keyboardHide = @"DOKeyboardHideNotification";
//不可修改否则borderview不能接收

#define FONT_OBLIQUITY 15.0
#define ANIMATION_DURATION .3

@interface do_TextBox_UIView() 
@property (nonatomic, strong) NSMutableDictionary *attributeDict;
@property (nonatomic, strong) UIFont *currentFont;
@property (nonatomic, strong) UIColor *currentTextColor;
@property (nonatomic, strong) NSString *myFontStyle;
@property (nonatomic, strong) NSString *myFontFlag;
@property (nonatomic, assign) int intFontSize;

@end

@implementation do_TextBox_UIView
{
    
    
    doInvokeResult *_invokeResult;
    
    NSString *_hintColor;
    
    BOOL _isEnabled;
    
    UITextView *_placeholderTextView;//默认提示框
    int maxLength;//设置文本可以显示的最大长度
    NSAttributedString *Hint;
    NSString *comText;
    
    NSInteger _maxLines;
}
#pragma mark - doIUIModuleView协议方法（必须）
//引用Model对象
- (void) LoadView: (doUIModule *) _doUIModule
{
    _model = (typeof(_model)) _doUIModule;
    
    self.delegate =self;
    //提示内容
    [self generatePlaceHolder];
    self.backgroundColor = [UIColor clearColor];

    _myFontStyle = @"normal";
    _myFontFlag = @"normal";
    _currentFont = [UIFont systemFontOfSize:[doUIModuleHelper GetDeviceFontSize:17 :_model.XZoom :_model.YZoom]];
    
    [self change_fontColor:[_model GetProperty:@"fontColor"].DefaultValue];
    [self change_hint:[_model GetProperty:@"hint"].DefaultValue];
    [self change_maxLength:[_model GetProperty:@"maxLength"].DefaultValue];
    [self change_fontSize:[_model GetProperty:@"fontSize"].DefaultValue];
    [self change_enabled:[_model GetProperty:@"enabled"].DefaultValue];
    [self change_cursorColor:[_model GetProperty:@"cursorColor"].DefaultValue];
    [self change_inputType:[_model GetProperty:@"inputType"].DefaultValue];
    _maxLines = [[_model GetProperty:@"maxLines"].DefaultValue integerValue];
    
    if (_maxLines<=0) {
        _maxLines = 65535;
    }
    self.spellCheckingType = UITextSpellCheckingTypeNo;
    self.autocorrectionType = UITextAutocorrectionTypeNo;
    _hintColor = [_model GetProperty:@"hintColor"].DefaultValue;
    
    _isEnabled = YES;
    
    
    _attributeDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      _currentFont,NSFontAttributeName,
                      _currentTextColor,NSForegroundColorAttributeName,
                      @(NSUnderlineStyleNone),NSUnderlineStyleAttributeName,nil];
}
- (BOOL)isAutoHeight
{
    return [[_model GetPropertyValue:@"height"] isEqualToString:@"-1"];
}
- (void)generatePlaceHolder
{
    _placeholderTextView = [[UITextView alloc] init];
    _placeholderTextView.userInteractionEnabled = FALSE;//由于默认不带默认提示消息，这个控件是在原来的控件上进行覆盖的，所以必须设置为false
    _placeholderTextView.layer.borderColor = [UIColor clearColor].CGColor;
    _placeholderTextView.layer.borderWidth = 2;
    _placeholderTextView.backgroundColor = [UIColor clearColor];
    _placeholderTextView.frame = CGRectMake(0, 0,[[doTextHelper Instance] StrToDouble:[_model GetPropertyValue:@"width"]:0],[[doTextHelper Instance] StrToDouble:[_model GetPropertyValue:@"height"]:30]);
    _placeholderTextView.textColor = [UIColor colorWithRed:204/255.0 green:204/255.0 blue:204/255.0 alpha:1.0];
    [self addSubview:_placeholderTextView];
}
//销毁所有的全局对象
- (void) OnDispose
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _myFontStyle = nil;
    _myFontFlag = nil;
    _invokeResult = nil;
    [_attributeDict removeAllObjects];
    _attributeDict = nil;
}
//实现布局
- (void) OnRedraw
{
    //实现布局相关的修改
    //重新调整视图的x,y,w,h
    [doUIModuleHelper OnRedraw:_model];
    [self adjustFrame];
    _placeholderTextView.frame = self.bounds;
}
- (void)adjustFrame
{
    if ([self isAutoHeight]) {
        if ((!self.text || self.text.length==0) && Hint.length>0) {
            CGSize newsize = [_placeholderTextView sizeThatFits:CGSizeMake(CGRectGetWidth(_placeholderTextView.frame), MAXFLOAT)];
            CGRect r = self.frame;
            r.size.height = newsize.height;
            self.frame = r;
        }else{
            CGSize newsize = [self sizeThatFits:CGSizeMake(CGRectGetWidth(self.frame), MAXFLOAT)];
            CGFloat height = newsize.height;

            if (self.text.length>0) {
                //判断最大行数
                NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
                CGRect rectAll = [self getContentRect:attrStr];

                //单行的高度
                attrStr = [[NSMutableAttributedString alloc] initWithString:@" "];
                CGRect rectLine = [self getContentRect:attrStr];
                int lines = round(CGRectGetHeight(rectAll)/CGRectGetHeight(rectLine));
                if (lines>=_maxLines) {
                    height = CGRectGetHeight(rectLine)*_maxLines;
                }
            }

            CGRect r = self.frame;
            r.size.height = height;
            self.frame = r;
        }
        
        self.bounces = NO;
        
        [self setNeedsLayout];
        
        [doUIModuleHelper OnResize:_model];
    }else
        self.bounces = YES;
    
    _placeholderTextView.frame = self.bounds;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:didBeginEdit object:self];
}

- (CGRect)getContentRect:(NSMutableAttributedString *)attrStr
{
    NSRange allRange = {0,[attrStr length]};
    [attrStr addAttribute:NSFontAttributeName
                    value:_currentFont
                    range:allRange];
    
    NSStringDrawingOptions options =  NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading | NSStringDrawingTruncatesLastVisibleLine;
    CGRect rect = [attrStr boundingRectWithSize:CGSizeMake(CGRectGetWidth(self.frame), MAXFLOAT) options:options context:nil];
    
    return rect;
}

#pragma mark - TYPEID_IView协议方法（必须）
#pragma mark - Changed_属性
/*
 如果在Model及父类中注册过 "属性"，可用这种方法获取
 NSString *属性名 = [(doUIModule *)_model GetPropertyValue:@"属性名"];
 
 获取属性最初的默认值
 NSString *属性名 = [(doUIModule *)_model GetProperty:@"属性名"].DefaultValue;
 */

- (void)change_enterText:(NSString *)newValue
{
    if ([newValue isEqualToString:@"go"]) {
        self.returnKeyType = UIReturnKeyGo;
    }
    else if ([newValue isEqualToString:@"send"])
    {
        self.returnKeyType = UIReturnKeySend;
    }
    else if ([newValue isEqualToString:@"next"])
    {
        self.returnKeyType = UIReturnKeyNext;
    }
    else if ([newValue isEqualToString:@"done"])
    {
        self.returnKeyType= UIReturnKeyDone;
    }
    else if ([newValue isEqualToString:@"search"])
    {
        self.returnKeyType=UIReturnKeySearch;
    }
    else//default
    {
        self.returnKeyType=UIReturnKeyDefault;
    }
    
}
- (void)change_enabled:(NSString *)newValue
{
    self.userInteractionEnabled = [newValue boolValue];
    self.editable = [newValue boolValue];
    _isEnabled = self.editable;
}
- (void)change_text:(NSString *)newValue{
    comText = newValue;
    UITextRange *range = self.selectedTextRange;
    NSInteger number = [newValue length];
    NSString *txt = newValue;
    BOOL _isBeyond = NO;
    if (maxLength>=0) {
        if (number > maxLength) {
            _isBeyond = YES;
            txt = [txt substringToIndex:maxLength];
        }
    }
    if (!self.markedTextRange) {
        [_model SetPropertyValue:@"text" :txt];
        if (!_isBeyond) {
            [self fireEvent];
        }
        if (_myFontFlag)
            [self change_textFlag:_myFontFlag];
        if(_myFontStyle)
            [self change_fontStyle:_myFontStyle];
        else
            [self setText:txt];
    }
    self.selectedTextRange = range;

    [self adjustFrame];
    
    NSRange scrollRange = [self selectedRange];
    self.selectedRange = scrollRange;
}
- (void)change_fontColor:(NSString *)newValue{
    _currentTextColor = [doUIModuleHelper GetColorFromString:newValue :[UIColor blackColor]];
    [_attributeDict setObject:_currentTextColor forKey:NSForegroundColorAttributeName];
    self.editable = YES;
    UIColor *fontColor = [doUIModuleHelper GetColorFromString:newValue :[UIColor blackColor]];
    [self setTextColor:fontColor];
    self.editable = _isEnabled;
}
- (void)change_fontSize:(NSString *)newValue{
    UIFont * font = [UIFont systemFontOfSize:[newValue intValue]];
    _intFontSize = [doUIModuleHelper GetDeviceFontSize:[[doTextHelper Instance] StrToInt:newValue :[[_model GetProperty:@"fontSize"].DefaultValue intValue]] :_model.XZoom :_model.YZoom];
    _currentFont = [font fontWithSize:_intFontSize];
    _placeholderTextView.font = _currentFont;
    
    if (_myFontFlag)
        [self change_textFlag:_myFontFlag];
    if(_myFontStyle)
        [self change_fontStyle:_myFontStyle];
    
    [self adjustFrame];
}
- (void)change_fontStyle:(NSString *)newValue
{
    //自己的代码实现
    _myFontStyle = [NSString stringWithFormat:@"%@",newValue];
    if (self.text==nil || [self.text isEqualToString:@""]) return;
    
    UIFont *font;
    if([newValue isEqualToString:@"normal"]) {
        [_attributeDict removeObjectForKey:NSObliquenessAttributeName];
        font = [UIFont systemFontOfSize:_intFontSize];
        
    }
    else if([newValue isEqualToString:@"bold"]) {
        [_attributeDict removeObjectForKey:NSObliquenessAttributeName];
        font = [UIFont boldSystemFontOfSize:_intFontSize];
    }
    else if([newValue isEqualToString:@"italic"])
    {
        [_attributeDict setObject:@0.33 forKey:NSObliquenessAttributeName];
        
        font = [UIFont systemFontOfSize:_intFontSize];
    }
    else if([newValue isEqualToString:@"bold_italic"]){
        [_attributeDict setObject:@0.33 forKey:NSObliquenessAttributeName];
        font = [UIFont boldSystemFontOfSize:_intFontSize];
    }
    [_attributeDict setObject:font forKey:NSFontAttributeName];
    _currentFont = font;
    
    self.attributedText = [[NSMutableAttributedString alloc] initWithString:self.text attributes:_attributeDict];

    
}
- (void)change_textFlag:(NSString *)newValue
{
    //自己的代码实现
    _myFontFlag = [NSString stringWithFormat:@"%@",newValue];
    NSString *currentText = [_model GetPropertyValue:@"text"];
    if (!IOS_8 && _intFontSize < 14) {
        [self setText:currentText];
        return;
    }
    if (!currentText || currentText.length == 0) {
        self.attributedText = [[NSAttributedString alloc] initWithString:@""];
        return;
    }
    
    if ([_myFontFlag isEqualToString:@"normal"]) {
        _attributeDict[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleNone);
        _attributeDict[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleNone);
    
    }else if ([_myFontFlag isEqualToString:@"underline"]) {
        _attributeDict[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
    
    }else if ([_myFontFlag isEqualToString:@"strikethrough"]) {
        [_attributeDict setObject:@(NSUnderlineStyleSingle) forKey:NSStrikethroughStyleAttributeName];
    }
    
    // 设置字体
    [_attributeDict setObject:_currentFont forKey:NSFontAttributeName];
    // 字体颜色
    [_attributeDict setObject:_currentTextColor forKey:NSForegroundColorAttributeName];
    
    self.attributedText = [[NSMutableAttributedString alloc] initWithString:currentText attributes:_attributeDict];
}
- (void)setAttributedText:(NSAttributedString *)attributedText
{
    [super setAttributedText:attributedText];
    if (attributedText.length == 0) {
        [self showHint];
    }else
    {
        [self dismissHint];
    }
}
- (void)change_hint:(NSString *)newValue
{
    if (!newValue || newValue.length == 0) {
        newValue = @"";
    }
    [self setHint:[[NSAttributedString alloc] initWithString:newValue]];
    [self change_hintColor:_hintColor];
    
    [self adjustFrame];
}
- (void)change_hintColor:(NSString *)newValue
{
    _hintColor = newValue;
    if (!newValue || newValue.length == 0 || !_placeholderTextView.attributedText || _placeholderTextView.attributedText.length == 0) {
        return;
    }
    NSString *defaultColor = [_model GetProperty:@"hintColor"].DefaultValue;
    UIColor *dColor = [doUIModuleHelper GetColorFromString:defaultColor :[UIColor blueColor]];
    UIColor *hintColor = [doUIModuleHelper GetColorFromString:newValue :dColor];
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:_placeholderTextView.text];
    NSRange placeRange = {0,_placeholderTextView.text.length};
    [string addAttribute:NSForegroundColorAttributeName value:hintColor range:placeRange];
    [string addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:_intFontSize] range:placeRange];
    [_placeholderTextView setAttributedText:string];

}
- (void)change_maxLines:(NSString *)newValue
{
    _maxLines = [newValue integerValue];
    if (_maxLines<=0) {
        _maxLines = 65535;
    }
}
- (void)change_maxLength:(NSString *)newValue
{
    maxLength = [[doTextHelper Instance] StrToInt:newValue :0];
    if (comText) {
        [self change_text:comText];
    }
}
- (void)change_cursorColor:(NSString *)newValue
{
    self.tintColor = [doUIModuleHelper GetColorFromString:newValue : [UIColor clearColor]];
}
- (void)setFocus:(NSArray *)params
{
    NSDictionary *dic = [params objectAtIndex:0];
    BOOL value = [doJsonHelper GetOneBoolean:dic :@"value" :NO];
    if (value) {
        [self becomeFirstResponder];
    }else
        [self resignFirstResponder];
}
- (void)setSelection:(NSArray *)parms
{
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    //自己的代码实现
    NSString *startStr = [doJsonHelper GetOneText:_dictParas :@"position" :@""];
//    [self Help_moveCursorWithDirection:UITextLayoutDirectionLeft offset:(self.text.length -[startStr integerValue])];
    self.selectedRange = NSMakeRange([startStr integerValue], 0);
}
- (void)Help_moveCursorWithDirection:(UITextLayoutDirection)direction offset:(NSInteger)offset
{
    UITextPosition* endPosition = self.endOfDocument;
    UITextPosition* start = [self positionFromPosition:endPosition inDirection:direction offset:offset];
    if (start)
    {
        [self setSelectedTextRange:[self textRangeFromPosition:start toPosition:start]];
    }
}

- (void)change_inputType:(NSString *)newValue {
    UIKeyboardType tempKeyBoardType;
    if ([newValue isEqualToString:@"ASC"]) {
        tempKeyBoardType = UIKeyboardTypeDefault;
    }else if([newValue isEqualToString:@"PHONENUMBER"]){
        tempKeyBoardType = UIKeyboardTypePhonePad;
    }else if([newValue isEqualToString:@"URL"]){
        tempKeyBoardType = UIKeyboardTypeURL;
    }else if ([newValue isEqualToString:@"ENG"]) {
        tempKeyBoardType = UIKeyboardTypeASCIICapable;
    }else if ([newValue isEqualToString:@"DECIMAL"]) {
        tempKeyBoardType = UIKeyboardTypeDecimalPad;
    }else{
        tempKeyBoardType = UIKeyboardTypeDefault;
    }
    self.keyboardType = tempKeyBoardType;
}



#pragma mark - private mothed
- (void) registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidBeginEditing:) name:UITextViewTextDidBeginEditingNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textViewChanged:) name:UITextViewTextDidChangeNotification object:nil];
}

- (void)removeObserver
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidBeginEditingNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidChangeNotification object:nil];
}

//输入框为空时显示的文字提示信息。灰色文字显示。
-(void)setHint:(NSAttributedString *)hint
{
    Hint = [hint copy];
    if (self.text.length == 0) {
        [self showHint];
    }
}

-(void)setText:(NSString *)Text
{
    [super setText:Text];
    if (Text.length == 0) {
        [self showHint];
    }else
    {
        [self dismissHint];
    }
}
#pragma mark -
#pragma mark - textFiled add private
-(void)OnTextChanged:(UITextView *)_textView
{
    if (_textView.text.length == 0) {
        [self showHint];
    }else{
        [self dismissHint];
    }
}
//显示提示内容，调用此方法的前提是内容为空
- (void)showHint
{
    _placeholderTextView.attributedText = Hint;
    [self change_hintColor:_hintColor];
}
//关闭显示内容
- (void)dismissHint
{
    _placeholderTextView.attributedText = nil;
}
#pragma mark - 私有方法
//visible=false，取消编辑状态
- (void)setHidden:(BOOL)_hidden
{
    [super setHidden:_hidden];
    [self resignFirstResponder];
}



#pragma mark - notification method
- (void) keyboardWasShown:(NSNotification *) notif
{
    NSDictionary *info = [notif userInfo];

    [[NSNotificationCenter defaultCenter] postNotificationName:keyboardShow object:self userInfo:info];
    
}
- (void)keyboardDidBeginEditing:(NSNotification *) notif
{
    NSDictionary *info = [notif userInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:didBeginEdit object:self userInfo:info];
    if ([self.text isEqualToString:@""]) {

        UIFont *font;
        if([_myFontStyle isEqualToString:@"normal"]) {
            [_attributeDict removeObjectForKey:NSObliquenessAttributeName];
            font = [UIFont systemFontOfSize:_intFontSize];

        }
        else if([_myFontStyle isEqualToString:@"bold"]) {
            [_attributeDict removeObjectForKey:NSObliquenessAttributeName];
            font = [UIFont boldSystemFontOfSize:_intFontSize];
        }
        else if([_myFontStyle isEqualToString:@"italic"])
        {
            [_attributeDict setObject:@0.33 forKey:NSObliquenessAttributeName];

            font = [UIFont systemFontOfSize:_intFontSize];
        }
        else if([_myFontStyle isEqualToString:@"bold_italic"]){
            [_attributeDict setObject:@0.33 forKey:NSObliquenessAttributeName];
            font = [UIFont boldSystemFontOfSize:_intFontSize];
        }
        [_attributeDict setObject:font forKey:NSFontAttributeName];

        self.attributedText = [[NSMutableAttributedString alloc] initWithString:@"*" attributes:_attributeDict];
        self.attributedText = nil;
    }
}

- (void)textViewChanged:(id)sender
{
    [self OnTextChanged:self];
    [self change_text:self.text];
    
    NSRange range = [self selectedRange];
    [self scrollRangeToVisible:NSMakeRange(range.location, 1)];
}

- (NSRange) selectedRange
{
    UITextPosition* beginning = self.beginningOfDocument;
    
    UITextRange* selectedRange = self.selectedTextRange;
    UITextPosition* selectionStart = selectedRange.start;
    UITextPosition* selectionEnd = selectedRange.end;
    
    const NSInteger location = [self offsetFromPosition:beginning toPosition:selectionStart];
    const NSInteger length = [self offsetFromPosition:selectionStart toPosition:selectionEnd];
    
    return NSMakeRange(location, length);
}

- (void)fireEvent
{
    if (!_invokeResult)     {
        _invokeResult = [[doInvokeResult alloc]init:_model.UniqueKey];
    }
    [_model.EventCenter FireEvent:@"textChanged":_invokeResult];
}

- (NSString *)textInRange:(UITextRange *)range
{
    NSString *txt = [super textInRange:range];
    if (maxLength<0) {
        return txt;
    }
    NSInteger number = [self.text length];
    if (number > maxLength) {
        return nil;
    }
    return txt;
}
#pragma mark - uitextViewDelegate

-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    //source 原来的文本
    //newtxt 改变后的文本
    NSMutableString *newtxt = [NSMutableString stringWithString:textView.text];
    NSString *sourceText = textView.text;
    [newtxt replaceCharactersInRange:range withString:text];
    
    [self scrollRangeToVisible:NSMakeRange(self.text.length, 1)];
    
    if ([text isEqualToString:@"\n"]) {
        [self fireEvent:@"enter"];
    }
    //输入法为ASC时，多个中文输入不上的bug
    NSString * lang = [[UIApplication sharedApplication]textInputMode].primaryLanguage;
    if ([lang isEqualToString:@"zh-Hans"] || [lang isEqualToString:@"es-ES"] || [lang isEqualToString:@"en-US"]) {
        UITextRange * selectedRange = [textView markedTextRange];
        UITextPosition * position = [textView positionFromPosition:selectedRange.start offset:0];
        if (!position) {
            if (maxLength >=0) {//只有maxlength是正数，才需要限制输入
                if (maxLength < sourceText.length || maxLength < newtxt.length) {//如果原来的文本比maxlength更长，则只允许删除
                    if (sourceText.length < newtxt.length) {
                        return NO;
                    }
                }
            }
        }
    }
    
    
//    if (maxLength >=0) {//只有maxlength是正数，才需要限制输入
//        if (maxLength < sourceText.length || maxLength < newtxt.length) {//如果原来的文本比maxlength更长，则只允许删除
//            if (sourceText.length < newtxt.length) {
//                return NO;
//            }
//        }
//    }
    return YES;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    [self fireEvent:@"focusIn"];
    [[NSNotificationCenter defaultCenter] postNotificationName:didBeginEdit object:self];
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    return YES;
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    [self removeObserver];
    [self fireEvent:@"focusOut"];
    if (textView.text.length == 0)
    {
        [self showHint];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:keyboardHide object:self];
}

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    [self registerForKeyboardNotifications];
    return YES;
}


-(void) fireEvent:(NSString*) _event
{
    doInvokeResult* _result = [[doInvokeResult alloc] init:_model.UniqueKey];
    [_model.EventCenter FireEvent:_event :_result ];
}

#pragma mark - doIUIModuleView协议方法（必须）<大部分情况不需修改>
- (BOOL) OnPropertiesChanging: (NSMutableDictionary *) _changedValues
{
    //属性改变时,返回NO，将不会执行Changed方法
    NSString *key = @"text";
    if ([_changedValues.allKeys containsObject:key]) {
        NSString *txt = [_changedValues objectForKey:key];
        NSInteger number = txt.length;
        if (maxLength>=0) {
            if (number > maxLength) {
                txt = [txt substringToIndex:maxLength];
                [_changedValues setObject:txt forKey:key];
            }
        }
    }
    return YES;
}
- (void) OnPropertiesChanged: (NSMutableDictionary*) _changedValues
{
    //_model的属性进行修改，同时调用self的对应的属性方法，修改视图
    [doUIModuleHelper HandleViewProperChanged: self :_model : _changedValues ];
}
- (BOOL) InvokeSyncMethod: (NSString *) _methodName : (NSDictionary *)_dicParas :(id<doIScriptEngine>)_scriptEngine : (doInvokeResult *) _invokeResults
{
    //同步消息
    return [doScriptEngineHelper InvokeSyncSelector:self : _methodName :_dicParas :_scriptEngine :_invokeResults];
}
- (BOOL) InvokeAsyncMethod: (NSString *) _methodName : (NSDictionary *) _dicParas :(id<doIScriptEngine>) _scriptEngine : (NSString *) _callbackFuncName
{
    //异步消息
    return [doScriptEngineHelper InvokeASyncSelector:self : _methodName :_dicParas :_scriptEngine: _callbackFuncName];
}
- (doUIModule *) GetModel
{
    //获取model对象
    return _model;
}
@end

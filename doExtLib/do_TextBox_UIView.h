//
//  TYPEID_View.h
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "do_TextBox_IView.h"
#import "doIUIModuleView.h"
#import "do_TextBox_UIModel.h"

@interface do_TextBox_UIView : UITextView<do_TextBox_IView,doIUIModuleView,UITextViewDelegate>
{
    @private
       __weak do_TextBox_UIModel *_model;
}
@end

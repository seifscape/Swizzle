//
//  TBBaseValueCell.h
//  TBTweakViewController
//
//  Created by Tanner on 8/26/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "TBTableViewCell.h"
#import "TBValue.h"
#import "TBValueCoordinator.h"


/// Delegate of value cells to make retreiving
/// responders and values easier.
@protocol TBValueCellDelegate

/// i.e. the text field where the value is being entered
@property (nonatomic) UIResponder *currentResponder;
@property (nonatomic, readonly) TBValueCoordinator *coordinator;
@property (nonatomic, readonly) UITableView *tableView;

- (void)didUpdateValue:(id)value;

@end


@interface TBBaseValueCell : TBTableViewCell

@property (nonatomic, readonly, class) NSArray<Class> *allValueCells;

@property (nonatomic, weak) id<TBValueCellDelegate> delegate;

- (void)describeValue:(TBValue *)value;

@end

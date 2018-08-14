//
//  CustomTaskController.m
//  LocalRadio
//
//  Created by Douglas Ward on 8/10/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//


/*
    JSON format for tasks database

    {
      "tasks" :
      [
        {
          "path": "/Applications/rtl-sdr/nrsc5-master/build/src/nrsc5",
          "arguments" : ["-q", "-o", "-", "-f", "wav", "89.1", "1"]
        }
      ],
      "sample_rate": "48000"
    }
*/

#import "CustomTaskController.h"
#import "SQLiteController.h"

@implementation CustomTaskController

- (id)init
{
    self = [super init];
    if (self)
    {
    
    }
    return self;
}



- (void)awakeFromNib
{
}





- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    NSInteger result = 0;
    
    if (tableView == self.nameTableView)
    {
        result = self.allCustomTasksArray.count;
    }
    else if (tableView == self.pathTableView)
    {
        result = [self numberOfRowsInPathTableView];
    }
    else if (tableView == self.argumentTableView)
    {
        result = [self numberOfRowsInArgumentTableView];
    }
    
    return result;
}



- (NSInteger)numberOfRowsInPathTableView
{
    NSInteger result = 0;

    NSIndexSet * selectedNameIndexSet = self.nameTableView.selectedRowIndexes;
    if (selectedNameIndexSet.count > 0)
    {
        NSInteger selectedNameIndex = selectedNameIndexSet.firstIndex;
        NSInteger numberOfItems = self.allCustomTasksArray.count;
        if (selectedNameIndex < numberOfItems)
        {
            NSDictionary * itemDictionary = [self.allCustomTasksArray objectAtIndex:selectedNameIndex];
            NSString * jsonString = [itemDictionary objectForKey:@"task_json"];
            if (jsonString != NULL)
            {
                if (jsonString.length > 0)
                {
                    NSData * jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                    
                    NSError * jsonError = NULL;
                    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
                    
                    if (jsonError == NULL)
                    {
                        if ([jsonObject isKindOfClass:[NSDictionary class]] == YES)
                        {
                            NSDictionary * jsonDictionary = jsonObject;
                            id tasksObject = [jsonDictionary objectForKey:@"tasks"];
                            if (tasksObject != NULL)
                            {
                                if ([tasksObject isKindOfClass:[NSArray class]] == YES)
                                {
                                    NSArray * tasksArray = tasksObject;
                                    result = tasksArray.count;
                                }
                            }
                            else
                            {
                                result = -6;
                            }
                        }
                        else
                        {
                            result = -5;
                        }
                    }
                    else
                    {
                        result = -4;
                    }
                }
                else
                {
                    result = -3;
                }
            }
            else
            {
                result = -2;
            }
        }
        else
        {
            result = -1;
        }
    }

    if (result < 0)
    {
        result = 0;
    }

    return result;
}



- (NSInteger)numberOfRowsInArgumentTableView
{
    NSInteger result = 0;

    NSIndexSet * selectedNameIndexSet = self.nameTableView.selectedRowIndexes;
    if (selectedNameIndexSet.count > 0)
    {
        NSInteger selectedNameIndex = selectedNameIndexSet.firstIndex;
        NSInteger numberOfItems = self.allCustomTasksArray.count;
        if (selectedNameIndex < numberOfItems)
        {
            NSDictionary * itemDictionary = [self.allCustomTasksArray objectAtIndex:selectedNameIndex];
            NSString * jsonString = [itemDictionary objectForKey:@"task_json"];
            if (jsonString != NULL)
            {
                if (jsonString.length > 0)
                {
                    NSData * jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                    
                    NSError * jsonError = NULL;
                    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
                    
                    if (jsonError == NULL)
                    {
                        if ([jsonObject isKindOfClass:[NSDictionary class]] == YES)
                        {
                            NSDictionary * jsonDictionary = jsonObject;
                            id tasksObject = [jsonDictionary objectForKey:@"tasks"];
                            if (tasksObject != NULL)
                            {
                                if ([tasksObject isKindOfClass:[NSArray class]] == YES)
                                {
                                    NSArray * tasksArray = tasksObject;

                                    NSIndexSet * selectedPathIndexSet = self.pathTableView.selectedRowIndexes;
                                    if (selectedPathIndexSet.count > 0)
                                    {
                                        NSInteger selectedPathIndex = selectedNameIndexSet.firstIndex;
                                        NSInteger numberOfPathItems = tasksArray.count;
                                        if (selectedPathIndex < numberOfPathItems)
                                        {
                                            id aTaskObject = [tasksArray objectAtIndex:selectedPathIndex];
                                            if ([aTaskObject isKindOfClass:[NSDictionary class]] == YES)
                                            {
                                                NSDictionary * aTaskDictionary = aTaskObject;
                                                id argumentsObject = [aTaskDictionary objectForKey:@"arguments"];
                                                if (argumentsObject != NULL)
                                                {
                                                    if ([argumentsObject isKindOfClass:[NSArray class]] == YES)
                                                    {
                                                        NSArray * argumentsArray = argumentsObject;
                                                        result = argumentsArray.count;
                                                    }
                                                    else
                                                    {
                                                        result = -13;
                                                    }
                                                }
                                                else
                                                {
                                                    result = -12;
                                                }
                                            }
                                            else
                                            {
                                                result = -11;
                                            }
                                        }
                                        else
                                        {
                                            result = -10;
                                        }
                                    }
                                    else
                                    {
                                        result = -8;
                                    }
                                }
                                else
                                {
                                    result = -7;
                                }
                            }
                            else
                            {
                                result = -6;
                            }
                        }
                        else
                        {
                            result = -5;
                        }
                    }
                    else
                    {
                        result = -4;
                    }
                }
                else
                {
                    result = -3;
                }
            }
            else
            {
                result = -2;
            }
        }
        else
        {
            result = -1;
        }
    }
    
    if (result < 0)
    {
        result = 0;
    }

    return result;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    id result = @"";

    if (tableView == self.nameTableView)
    {
        result = [self objectValueForNameTableColumn:tableColumn row:row];
    }
    else if (tableView == self.pathTableView)
    {
        result = [self objectValueForPathTableColumn:tableColumn row:row];
    }
    else if (tableView == self.argumentTableView)
    {
        result = [self objectValueForArgumentsTableColumn:tableColumn row:row];
    }
    
    return result;
}


- (id)objectValueForNameTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    id result = @"";

    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"name"])
    {
        NSInteger numberOfItems = self.allCustomTasksArray.count;
        if (row < numberOfItems)
        {
            NSDictionary * itemDictionary = [self.allCustomTasksArray objectAtIndex:row];
            NSString * nameString = [itemDictionary objectForKey:@"task_name"];
            if (nameString != NULL)
            {
                if (nameString.length > 0)
                {
                    result = nameString;
                }
                else
                {
                    result = @"Name Missing";
                }
            }
            else
            {
                result = @"Invalid Record";
            }
        }
        else
        {
            result = @"Invalid Row";
        }
    }
    return result;
}



- (id)objectValueForPathTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    id result = @"";

    NSString * identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"path"])
    {
        NSIndexSet * selectedNameIndexSet = self.nameTableView.selectedRowIndexes;
        if (selectedNameIndexSet.count > 0)
        {
            NSInteger selectedNameIndex = selectedNameIndexSet.firstIndex;
            NSInteger numberOfItems = self.allCustomTasksArray.count;
            if (selectedNameIndex < numberOfItems)
            {
                NSDictionary * itemDictionary = [self.allCustomTasksArray objectAtIndex:row];
                NSString * jsonString = [itemDictionary objectForKey:@"task_json"];
                if (jsonString != NULL)
                {
                    if (jsonString.length > 0)
                    {
                        NSData * jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                        
                        NSError * jsonError = NULL;
                        id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
                        
                        if (jsonError == NULL)
                        {
                            if ([jsonObject isKindOfClass:[NSDictionary class]] == YES)
                            {
                                NSDictionary * jsonDictionary = jsonObject;
                                id tasksObject = [jsonDictionary objectForKey:@"tasks"];
                                if (tasksObject != NULL)
                                {
                                    if ([tasksObject isKindOfClass:[NSArray class]] == YES)
                                    {
                                        NSArray * tasksArray = tasksObject;
                                        
                                        id taskObject = [tasksArray objectAtIndex:selectedNameIndex];
                                        
                                        if (taskObject != NULL)
                                        {
                                            if ([taskObject isKindOfClass:[NSDictionary class]] == YES)
                                            {
                                                NSDictionary * aTaskDictionary = taskObject;
                                                
                                                NSString * pathString = [aTaskDictionary objectForKey:@"path"];
                                                
                                                if (pathString != NULL)
                                                {
                                                    if (pathString.length > 0)
                                                    {
                                                        result = pathString;
                                                    }
                                                    else
                                                    {
                                                        result = @"Missing path";
                                                    }
                                                }
                                                else
                                                {
                                                    result = @"Invalid path";
                                                }
                                            }
                                            else
                                            {
                                                result = @"Invalid task class";
                                            }
                                        }
                                        else
                                        {
                                            result = @"Missing task dictionary";
                                        }
                                    }
                                }
                                else
                                {
                                    result = @"tasks array missing";
                                }
                            }
                            else
                            {
                                result = @"JSON class error";
                            }
                        }
                        else
                        {
                            result = @"JSON Error";
                        }
                    }
                    else
                    {
                        result = @"JSON Missing";
                    }
                }
                else
                {
                    result = @"Invalid Record";
                }
            }
            else
            {
                result = @"Invalid Row";
            }
        }
    }
    return result;
}





- (id)objectValueForArgumentsTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    id result = NULL;

    NSString * identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"arguments"])
    {
        NSArray * selectedArgumentsArray = [self selectedArgumentsArray];
        if (selectedArgumentsArray != NULL)
        {
            if (row < selectedArgumentsArray.count)
            {
                NSString * argumentString = [selectedArgumentsArray objectAtIndex:row];
                if (argumentString != NULL)
                {
                    result = argumentString;
                }
                else
                {
                    result = @"error -15";
                }
            }
            else
            {
                result = @"error -14";
            }
        }
    }
    return result;
}



- (NSArray *)selectedArgumentsArray
{
    NSArray * result = NULL;

    NSIndexSet * selectedNameIndexSet = self.nameTableView.selectedRowIndexes;
    if (selectedNameIndexSet.count > 0)
    {
        NSInteger selectedNameIndex = selectedNameIndexSet.firstIndex;
        NSInteger numberOfItems = self.allCustomTasksArray.count;
        if (selectedNameIndex < numberOfItems)
        {
            NSDictionary * itemDictionary = [self.allCustomTasksArray objectAtIndex:selectedNameIndex];
            NSString * jsonString = [itemDictionary objectForKey:@"task_json"];
            if (jsonString != NULL)
            {
                if (jsonString.length > 0)
                {
                    NSData * jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                    
                    NSError * jsonError = NULL;
                    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
                    
                    if (jsonError == NULL)
                    {
                        if ([jsonObject isKindOfClass:[NSDictionary class]] == YES)
                        {
                            NSDictionary * jsonDictionary = jsonObject;
                            id tasksObject = [jsonDictionary objectForKey:@"tasks"];
                            if (tasksObject != NULL)
                            {
                                if ([tasksObject isKindOfClass:[NSArray class]] == YES)
                                {
                                    NSArray * tasksArray = tasksObject;

                                    NSIndexSet * selectedPathIndexSet = self.pathTableView.selectedRowIndexes;
                                    if (selectedPathIndexSet.count > 0)
                                    {
                                        NSInteger selectedPathIndex = selectedNameIndexSet.firstIndex;
                                        NSInteger numberOfPathItems = tasksArray.count;
                                        if (selectedPathIndex < numberOfPathItems)
                                        {
                                            id aTaskObject = [tasksArray objectAtIndex:selectedPathIndex];
                                            if ([aTaskObject isKindOfClass:[NSDictionary class]] == YES)
                                            {
                                                NSDictionary * aTaskDictionary = aTaskObject;
                                                id argumentsObject = [aTaskDictionary objectForKey:@"arguments"];
                                                if (argumentsObject != NULL)
                                                {
                                                    if ([argumentsObject isKindOfClass:[NSArray class]] == YES)
                                                    {
                                                        NSArray * argumentsArray = argumentsObject;
                                                        result = argumentsArray;
                                                    }
                                                    else
                                                    {
                                                        //result = @"error -13";
                                                    }
                                                }
                                                else
                                                {
                                                    //result = @"error -12";
                                                }
                                            }
                                            else
                                            {
                                                //result = @"error -11";
                                            }
                                        }
                                        else
                                        {
                                            //result = @"error -10";
                                        }
                                    }
                                    else
                                    {
                                        //result = @"error -9";
                                    }
                                }
                                else
                                {
                                    //result = @"error -8";
                                }
                            }
                            else
                            {
                                //result = @"error -7";
                            }
                        }
                        else
                        {
                            //result = @"error -6";
                        }
                    }
                    else
                    {
                        //result = @"error -5";
                    }
                }
                else
                {
                    //result = @"error -4";
                }
            }
            else
            {
                //result = @"error -3";
            }
        }
        else
        {
            //result = @"error -2";
        }
    }

    return result;
}


- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *identifier = tableColumn.identifier;
    
    if ([identifier isEqualToString:@"name"])
    {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
        cellView.textField.stringValue = [self tableView:tableView objectValueForTableColumn:tableColumn row:row];
        cellView.textField.editable = YES;
        cellView.textField.target = self;
        cellView.textField.action = @selector(onEnterInTextField:);
        cellView.textField.identifier = @"name";
        return cellView;
    }
    else if ([identifier isEqualToString:@"path"])
    {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
        cellView.textField.stringValue = [self tableView:tableView objectValueForTableColumn:tableColumn row:row];
        cellView.textField.editable = YES;
        cellView.textField.target = self;
        cellView.textField.action = @selector(onEnterInTextField:);
        cellView.textField.identifier = @"path";
        return cellView;
    }
    else if ([identifier isEqualToString:@"arguments"])
    {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
        cellView.textField.stringValue = [self tableView:tableView objectValueForTableColumn:tableColumn row:row];
        cellView.textField.editable = YES;
        cellView.textField.target = self;
        cellView.textField.action = @selector(onEnterInTextField:);
        cellView.textField.identifier = @"arguments";
        return cellView;
    }
    else
    {
        NSAssert1(NO, @"Unhandled table column identifier %@", identifier);
    }
    return nil;
}



- (void) updateTaskNamesArray
{
    self.allCustomTasksArray = [[self.sqliteController allCustomTaskRecords] mutableCopy];
    
    [self.nameTableView reloadData];
    [self.pathTableView reloadData];
    [self.argumentTableView reloadData];
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSTableView * tableView = notification.object;
    if (tableView == self.nameTableView)
    {
        [self.pathTableView reloadData];
        [self.argumentTableView reloadData];
    }
    else if (tableView == self.pathTableView)
    {
        [self.argumentTableView reloadData];
    }
    else if (tableView == self.argumentTableView)
    {
    }
}



- (IBAction)onEnterInTextField:(NSTextField *)sender
{
/*
    NSInteger selectedRowNumber = tableView.selectedRow;

    if (selectedRowNumber != -1)
    {
    
    }
*/
    NSLog(@"sender.identifier = %@", sender.identifier);
    
    NSString * identifier = sender.identifier;
    
    if ([identifier isEqualToString:@"name"] == YES)
    {
    
    }
    else if ([identifier isEqualToString:@"path"] == YES)
    {
    
    }
    else if ([identifier isEqualToString:@"arguments"] == YES)
    {
    
    }
    else if ([identifier isEqualToString:@"sample_rate"] == YES)
    {
    
    }
    else if ([identifier isEqualToString:@"channels"] == YES)
    {
    
    }

    NSBeep();
}


@end

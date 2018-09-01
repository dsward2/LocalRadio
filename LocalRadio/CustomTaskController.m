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
    self.previousSelectedCustomTaskID = NULL;
    self.previousNameTableSelectedRow = -1;
    self.previousPathTableSelectedRow = -1;
    self.previousArgumentsTableSelectedRow = -1;
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
                                        NSInteger selectedPathIndex = selectedPathIndexSet.firstIndex;
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
                                        
                                        id taskObject = [tasksArray objectAtIndex:row];
                                        
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
                                        NSInteger selectedPathIndex = selectedPathIndexSet.firstIndex;
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
    
    [self getExistingSelections];
    [self.nameTableView reloadData];
    [self.pathTableView reloadData];
    [self.argumentTableView reloadData];
    [self reselectRecord];
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSTableView * tableView = notification.object;
    if (tableView == self.nameTableView)
    {
        [self updateSampleRateAndChannels];
        [self.pathTableView reloadData];
        [self.argumentTableView reloadData];
    }
    else if (tableView == self.pathTableView)
    {
        [self.argumentTableView reloadData];
        
        [self reselectRecord];
    }
    else if (tableView == self.argumentTableView)
    {
    }
}


- (void)updateSampleRateAndChannels
{
    BOOL dataFound = NO;

    NSIndexSet * selectedNameIndexSet = self.nameTableView.selectedRowIndexes;
    if (selectedNameIndexSet.count > 0)
    {
        NSInteger selectedNameIndex = selectedNameIndexSet.firstIndex;
        NSInteger numberOfItems = self.allCustomTasksArray.count;
        if (selectedNameIndex < numberOfItems)
        {
            NSDictionary * itemDictionary = [self.allCustomTasksArray objectAtIndex:selectedNameIndex];
            if (itemDictionary != NULL)
            {
                NSString * sampleRateString = [itemDictionary objectForKey:@"sample_rate"];
                if (sampleRateString == NULL)
                {
                    sampleRateString = @"";
                }
                self.sampleRateTextField.stringValue = sampleRateString;

                NSString * channelsString = [itemDictionary objectForKey:@"channels"];
                if (channelsString == NULL)
                {
                    channelsString = @"";
                }
                self.channelsTextField.stringValue = channelsString;
                
                NSString * inputBufferSizeString = [itemDictionary objectForKey:@"input_buffer_size"];
                if (inputBufferSizeString == NULL)
                {
                    inputBufferSizeString = @"256";
                }
                self.inputBufferSizeTextField.stringValue = inputBufferSizeString;
                
                NSString * audioConverterBufferSizeString = [itemDictionary objectForKey:@"audioconverter_buffer_size"];
                if (audioConverterBufferSizeString == NULL)
                {
                    audioConverterBufferSizeString = @"256";
                }
                self.audioConverterBufferSizeTextField.stringValue = audioConverterBufferSizeString;
                
                NSString * audioQueueBufferSizeString = [itemDictionary objectForKey:@"audioqueue_buffer_size"];
                if (audioQueueBufferSizeString == NULL)
                {
                    audioQueueBufferSizeString = @"256";
                }
                self.audioQueueBufferSizeTextField.stringValue = audioQueueBufferSizeString;
                
                dataFound = YES;
            }
        }
    }
    
    if (dataFound == NO)
    {
        self.sampleRateTextField.stringValue = @"";
        self.channelsTextField.stringValue = @"";
        self.inputBufferSizeTextField.stringValue = @"";
        self.audioConverterBufferSizeTextField.stringValue = @"";
        self.audioQueueBufferSizeTextField.stringValue = @"";
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

    NSIndexSet * selectedNameIndexSet = self.nameTableView.selectedRowIndexes;
    if (selectedNameIndexSet.count > 0)
    {
        NSInteger selectedNameIndex = selectedNameIndexSet.firstIndex;
        NSInteger numberOfNameItems = self.allCustomTasksArray.count;
        if (selectedNameIndex < numberOfNameItems)
        {
            NSMutableDictionary * itemDictionary = [[self.allCustomTasksArray objectAtIndex:selectedNameIndex] mutableCopy];
            NSString * taskJSON = [itemDictionary objectForKey:@"task_json"];

            NSString * identifier = sender.identifier;
            
            if ([identifier isEqualToString:@"name"] == YES)
            {
                [itemDictionary setObject:sender.stringValue forKey:@"task_name"];
            }
            else if ([identifier isEqualToString:@"path"] == YES)
            {
                NSIndexSet * selectedPathIndexSet = self.pathTableView.selectedRowIndexes;
                if (selectedPathIndexSet.count > 0)
                {
                    NSInteger selectedPathIndex = selectedPathIndexSet.firstIndex;
                    NSInteger numberOfPathItems = self.allCustomTasksArray.count;
                    if (selectedPathIndex < numberOfPathItems)
                    {
                        NSData * jsonData = [taskJSON dataUsingEncoding:NSUTF8StringEncoding];
                        NSError * jsonError = NULL;
                        NSMutableDictionary * jsonDictionary = [[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError] mutableCopy];

                        NSMutableArray * tasksArray = [[jsonDictionary objectForKey:@"tasks"] mutableCopy];
                        NSMutableDictionary * selectedTaskDictionary = [[tasksArray objectAtIndex:selectedPathIndex] mutableCopy];

                        [selectedTaskDictionary setObject:sender.stringValue forKey:@"path"];
                        [tasksArray replaceObjectAtIndex:selectedPathIndex withObject:selectedTaskDictionary];
                        [jsonDictionary setObject:tasksArray forKey:@"tasks"];

                        NSError * newJSONError = NULL;
                        NSData * newJSONData =  [NSJSONSerialization dataWithJSONObject:jsonDictionary options:0 error:&newJSONError];
                        NSString * newJSONString = [[NSString alloc] initWithData:newJSONData encoding:NSUTF8StringEncoding];
                        [itemDictionary setObject:newJSONString forKey:@"task_json"];
                    }
                }
            }
            else if ([identifier isEqualToString:@"arguments"] == YES)
            {
                NSIndexSet * selectedPathIndexSet = self.pathTableView.selectedRowIndexes;
                if (selectedPathIndexSet.count > 0)
                {
                    NSInteger selectedPathIndex = selectedPathIndexSet.firstIndex;
                    NSInteger numberOfPathItems = self.allCustomTasksArray.count;
                    if (selectedPathIndex < numberOfPathItems)
                    {
                        NSData * jsonData = [taskJSON dataUsingEncoding:NSUTF8StringEncoding];
                        NSError * jsonError = NULL;
                        NSMutableDictionary * jsonDictionary = [[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError] mutableCopy];

                        NSMutableArray * tasksArray = [[jsonDictionary objectForKey:@"tasks"] mutableCopy];
                        NSMutableDictionary * selectedTaskDictionary = [[tasksArray objectAtIndex:selectedPathIndex] mutableCopy];
                        
                        NSMutableArray * argumentsArray = [[selectedTaskDictionary objectForKey:@"arguments"] mutableCopy];

                        NSIndexSet * selectedArgumentIndexSet = self.argumentTableView.selectedRowIndexes;
                        if (selectedArgumentIndexSet.count > 0)
                        {
                            NSInteger selectedArgumentIndex = selectedArgumentIndexSet.firstIndex;
                            NSInteger numberOfArgumentsItems = argumentsArray.count;
                            if (selectedArgumentIndex < numberOfArgumentsItems)
                            {
                                [argumentsArray replaceObjectAtIndex:selectedArgumentIndex withObject:sender.stringValue];
                                [selectedTaskDictionary setObject:argumentsArray forKey:@"arguments"];
                                [tasksArray replaceObjectAtIndex:selectedPathIndex withObject:selectedTaskDictionary];
                                [jsonDictionary setObject:tasksArray forKey:@"tasks"];

                                NSError * newJSONError = NULL;
                                NSData * newJSONData =  [NSJSONSerialization dataWithJSONObject:jsonDictionary options:0 error:&newJSONError];
                                NSString * newJSONString = [[NSString alloc] initWithData:newJSONData encoding:NSUTF8StringEncoding];
                                [itemDictionary setObject:newJSONString forKey:@"task_json"];
                            }
                        }
                    }
                }
            }
            else if ([identifier isEqualToString:@"sample_rate"] == YES)
            {
                NSNumber * sampleRateNumber = [NSNumber numberWithInteger:self.sampleRateTextField.integerValue];
                [itemDictionary setObject:sampleRateNumber forKey:@"sample_rate"];
            }
            else if ([identifier isEqualToString:@"channels"] == YES)
            {
                NSNumber * channelsNumber = [NSNumber numberWithInteger:self.channelsTextField.integerValue];
                [itemDictionary setObject:channelsNumber forKey:@"channels"];
            }
            else if ([identifier isEqualToString:@"input_buffer_size"] == YES)
            {
                NSNumber * inputBufferSizeNumber = [NSNumber numberWithInteger:self.inputBufferSizeTextField.integerValue];
                [itemDictionary setObject:inputBufferSizeNumber forKey:@"input_buffer_size"];
            }
            else if ([identifier isEqualToString:@"audioconverter_buffer_size"] == YES)
            {
                NSNumber * audioConverterBufferSizeNumber = [NSNumber numberWithInteger:self.audioConverterBufferSizeTextField.integerValue];
                [itemDictionary setObject:audioConverterBufferSizeNumber forKey:@"audioconverter_buffer_size"];
            }
            else if ([identifier isEqualToString:@"audioqueue_buffer_size"] == YES)
            {
                NSNumber * audioQueueBufferSizeNumber = [NSNumber numberWithInteger:self.audioQueueBufferSizeTextField.integerValue];
                [itemDictionary setObject:audioQueueBufferSizeNumber forKey:@"audioqueue_buffer_size"];
            }

            [self.allCustomTasksArray replaceObjectAtIndex:selectedNameIndex withObject:itemDictionary];
            
            [self updateSelectedRecord];
        }
    }
}





- (void)updateSelectedRecord
{
    NSIndexSet * selectedNameIndexSet = self.nameTableView.selectedRowIndexes;
    if (selectedNameIndexSet.count > 0)
    {
        NSInteger selectedNameIndex = selectedNameIndexSet.firstIndex;
        NSInteger numberOfItems = self.allCustomTasksArray.count;
        if (selectedNameIndex < numberOfItems)
        {
            NSDictionary * itemDictionary = [self.allCustomTasksArray objectAtIndex:selectedNameIndex];
            
            NSLog(@"%@", itemDictionary);
            
            NSString * customTaskID = [itemDictionary objectForKey:@"id"];
            NSString * customTaskName = [itemDictionary objectForKey:@"task_name"];
            NSString * customTaskJSON = [itemDictionary objectForKey:@"task_json"];
            NSNumber * sampleRate = [itemDictionary objectForKey:@"sample_rate"];
            NSNumber * channels = [itemDictionary objectForKey:@"channels"];

            [self.sqliteController updateCustomTaskRecordForID:customTaskID name:customTaskName json:customTaskJSON sampleRate:sampleRate.integerValue channels:channels.integerValue];
        }
    }
}



- (IBAction)addTaskName:(id)sender
{
    NSString * timestamp = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970] * 1000];
    NSString * customTaskName = [NSString stringWithFormat:@"Custom Task %@", timestamp];
    NSString * customTaskJSON = @"{\"tasks\":[{\"path\": \"/Applications/LocalRadio.app/Contents/MacOS/rtl_fm_localradio\",\"arguments\" : [\"-M\", \"fm\", \"-l\", \"0\", \"-t\", \"0\", \"-F\", \"9\", \"-g\", \"49.6\", \"-s\", \"170000\", \"-o\", \"2\", \"-A\", \"std\", \"-p\", \"0\", \"-c\", \"17004\", \"-E\", \"pad\", \"-f\", \"89100000\"]}],}";
    NSInteger sampleRate = 170000;
    NSInteger channels = 1;
    
    [self.sqliteController insertCustomTaskRecord:customTaskName json:customTaskJSON sampleRate:sampleRate channels:channels];
    
    self.allCustomTasksArray = [[self.sqliteController allCustomTaskRecords] mutableCopy];

    [self getExistingSelections];
    [self.nameTableView reloadData];
    [self.pathTableView reloadData];
    [self.argumentTableView reloadData];
    
    NSIndexSet * indexSet = [NSIndexSet indexSetWithIndex:self.previousNameTableSelectedRow];
    [self.nameTableView selectRowIndexes:indexSet byExtendingSelection:NO];
}


- (IBAction)duplicateTaskName:(id)sender
{
    NSInteger selectedRow = self.nameTableView.selectedRow;
    
    if (selectedRow >= 0)
    {
        if (selectedRow < self.allCustomTasksArray.count)
        {
            NSDictionary * customTaskDictionary = [self.allCustomTasksArray objectAtIndex:selectedRow];
            
            NSString * timestamp = [NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970] * 1000];
            NSString * customTaskName = [NSString stringWithFormat:@"Custom Task %@", timestamp];
            
            NSString * customTaskJSON = [customTaskDictionary objectForKey:@"task_json"];
            
            NSNumber * sampleRateNumber = [customTaskDictionary objectForKey:@"sample_rate"];
            NSInteger sampleRate = sampleRateNumber.integerValue;
            
            NSNumber * channelsNumber = [customTaskDictionary objectForKey:@"channels"];
            NSInteger channels = channelsNumber.integerValue;
            
            [self.sqliteController insertCustomTaskRecord:customTaskName json:customTaskJSON sampleRate:sampleRate channels:channels];
            
            self.allCustomTasksArray = [[self.sqliteController allCustomTaskRecords] mutableCopy];

            [self getExistingSelections];
            [self.nameTableView reloadData];
            [self.pathTableView reloadData];
            [self.argumentTableView reloadData];
    
            NSIndexSet * indexSet = [NSIndexSet indexSetWithIndex:self.allCustomTasksArray.count - 1];
            [self.nameTableView selectRowIndexes:indexSet byExtendingSelection:NO];
            
            [self.nameTableView scrollRowToVisible:self.allCustomTasksArray.count - 1];
        }
        else
        {
            NSBeep();
        }
    }
    else
    {
        NSBeep();
    }
}

- (IBAction)deleteTaskName:(id)sender
{
    NSInteger selectedRow = self.nameTableView.selectedRow;
    
    if (selectedRow >= 0)
    {
        if (selectedRow < self.allCustomTasksArray.count)
        {
            NSDictionary * customTaskDictionary = [self.allCustomTasksArray objectAtIndex:selectedRow];
            
            NSNumber * taskIDNumber = [customTaskDictionary objectForKey:@"id"];
            NSString * taskIDString = taskIDNumber.stringValue;
        
            if (taskIDString != NULL)
            {
                [self.sqliteController deleteCustomTaskRecordForID:taskIDString];

                self.allCustomTasksArray = [[self.sqliteController allCustomTaskRecords] mutableCopy];

                [self getExistingSelections];
                [self.nameTableView reloadData];
                [self.pathTableView reloadData];
                [self.argumentTableView reloadData];

                if (selectedRow < self.allCustomTasksArray.count)
                {
                    NSIndexSet * rowIndexes = [NSIndexSet indexSetWithIndex:selectedRow];
                    [self.nameTableView selectRowIndexes:rowIndexes byExtendingSelection:NO];
                }
                else
                {
                    if (self.allCustomTasksArray.count > 0)
                    {
                        NSIndexSet * rowIndexes = [NSIndexSet indexSetWithIndex:self.allCustomTasksArray.count - 1];
                        [self.nameTableView selectRowIndexes:rowIndexes byExtendingSelection:NO];
                    }
                    else
                    {
                        [self.nameTableView deselectAll:self];
                    }
                }
            }
            else
            {
                NSBeep();
            }
        }
        else
        {
            NSBeep();
        }
    }
    else
    {
        NSBeep();
    }
}


- (IBAction)addTaskPath:(id)sender
{
    NSInteger selectedCustomTaskRow = self.nameTableView.selectedRow;
    NSInteger newSelectedRow = -1;
    
    if (selectedCustomTaskRow >= 0)
    {
        if (selectedCustomTaskRow < self.allCustomTasksArray.count)
        {
            NSMutableDictionary * customTaskDictionary = [[self.allCustomTasksArray objectAtIndex:selectedCustomTaskRow] mutableCopy];
            
            NSNumber * taskIDNumber = [customTaskDictionary objectForKey:@"id"];
            NSString * taskIDString = taskIDNumber.stringValue;
            
            NSString * taskName = [customTaskDictionary objectForKey:@"task_name"];
            
            NSNumber * sampleRateNumber = [customTaskDictionary objectForKey:@"sample_rate"];
            NSInteger sampleRate = sampleRateNumber.integerValue;
            
            NSNumber * channelsNumber = [customTaskDictionary objectForKey:@"channels"];
            NSInteger channels = channelsNumber.integerValue;

            NSString * customTaskJSON = [[customTaskDictionary objectForKey:@"task_json"] mutableCopy];
            if (customTaskJSON == NULL)
            {
                customTaskJSON = @"{\"tasks\":[{\"path\": \"/Applications/LocalRadio.app/Contents/MacOS/rtl_fm_localradio\",\"arguments\" : [\"-M\", \"fm\", \"-l\", \"0\", \"-t\", \"0\", \"-F\", \"9\", \"-g\", \"49.6\", \"-s\", \"170000\", \"-o\", \"2\", \"-A\", \"std\", \"-p\", \"0\", \"-c\", \"17004\", \"-E\", \"pad\", \"-f\", \"89100000\"]}],}";
            }
            
            NSData * jsonData = [customTaskJSON dataUsingEncoding:NSUTF8StringEncoding];
            NSError * jsonError = NULL;
            NSMutableDictionary * jsonDictionary = [[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError] mutableCopy];

            NSMutableArray * tasksArray = [[jsonDictionary objectForKey:@"tasks"] mutableCopy];
            if (tasksArray == NULL)
            {
                tasksArray = [NSMutableArray array];
            }
            
            NSInteger existingTasksArrayCount = tasksArray.count;
            
            NSMutableDictionary * newTaskDictionary = [NSMutableDictionary dictionary];
            
            if (existingTasksArrayCount == 0)
            {
                [newTaskDictionary setObject:@"/Applications/LocalRadio.app/Contents/MacOS/rtl_fm_localradio" forKey:@"path"];
                
                NSMutableArray * newTaskArgumentsArray = [NSMutableArray arrayWithObjects:@"-M", @"fm", @"-l", @"0", @"-t", @"0", @"-F", @"9", @"-g", @"49.6", @"-s", @"170000", @"-o", @"2", @"-A", @"std", @"-p", @"0", @"-c", @"17004", @"-E", @"pad", @"-f", @"89100000", NULL];
                [newTaskDictionary setObject:newTaskArgumentsArray forKey:@"arguments"];
            }
            else
            {
                [newTaskDictionary setObject:@"/Applications/LocalRadio.app/Contents/MacOS/sox" forKey:@"path"];
                
                NSMutableArray * newTaskArgumentsArray = [NSMutableArray arrayWithObjects:@"-V2", @"-q", @"-r", @"48000", @"-e", @"signed-integer", @"-b", @"16", @"-c", @"1", @"-t", @"raw", @"-", @"-e", @"signed-integer", @"-b", @"16", @"-c", @"1", @"-t", @"raw", @"-", @"rate", @"48000", @"vol", @"1", @"dither", @"-s", NULL];
                [newTaskDictionary setObject:newTaskArgumentsArray forKey:@"arguments"];
            }

            NSInteger selectedPathRow = self.pathTableView.selectedRow;

            if (selectedPathRow == -1)
            {
                [tasksArray addObject:newTaskDictionary];
                
                newSelectedRow = tasksArray.count - 1;
            }
            else
            {
                [tasksArray insertObject:newTaskDictionary atIndex:selectedPathRow + 1];

                newSelectedRow = selectedPathRow + 1;
            }

            newSelectedRow = [tasksArray indexOfObject:newTaskDictionary];

            [jsonDictionary setObject:tasksArray forKey:@"tasks"];
            
            NSError * newJSONError = NULL;
            NSData * newJSONData = [NSJSONSerialization dataWithJSONObject:jsonDictionary options:0 error:&newJSONError];
            NSString * newJSONString = [[NSString alloc] initWithData:newJSONData encoding:NSUTF8StringEncoding];
            
            [customTaskDictionary setObject:newJSONString forKey:@"task_json"];

            [self.allCustomTasksArray replaceObjectAtIndex:selectedCustomTaskRow withObject:customTaskDictionary];
            
            [self.sqliteController updateCustomTaskRecordForID:taskIDString name:taskName json:newJSONString sampleRate:sampleRate channels:channels];
        }
    }
    
    self.allCustomTasksArray = [[self.sqliteController allCustomTaskRecords] mutableCopy];

    [self getExistingSelections];
    [self.nameTableView reloadData];
    [self.pathTableView reloadData];
    [self.argumentTableView reloadData];
    [self reselectRecord];
    
    if (newSelectedRow > -1)
    {
        NSIndexSet * rowIndexes = [NSIndexSet indexSetWithIndex:newSelectedRow];
        [self.pathTableView selectRowIndexes:rowIndexes byExtendingSelection:NO];
    }
}


- (IBAction)deleteTaskPath:(id)sender
{
    NSInteger nameTableSelectedRow = self.nameTableView.selectedRow;
    if (nameTableSelectedRow >= 0)
    {
        if (nameTableSelectedRow < self.allCustomTasksArray.count)
        {
            NSInteger pathTableSelectedRow = self.pathTableView.selectedRow;
            if (pathTableSelectedRow >= 0)
            {
                NSMutableDictionary * customTaskDictionary = [[self.allCustomTasksArray objectAtIndex:nameTableSelectedRow] mutableCopy];
                
                NSNumber * taskIDNumber = [customTaskDictionary objectForKey:@"id"];
                NSString * taskIDString = taskIDNumber.stringValue;
                
                NSString * taskName = [customTaskDictionary objectForKey:@"task_name"];
                
                NSNumber * sampleRateNumber = [customTaskDictionary objectForKey:@"sample_rate"];
                NSInteger sampleRate = sampleRateNumber.integerValue;
                
                NSNumber * channelsNumber = [customTaskDictionary objectForKey:@"channels"];
                NSInteger channels = channelsNumber.integerValue;

                NSString * customTaskJSON = [[customTaskDictionary objectForKey:@"task_json"] mutableCopy];
                if (customTaskJSON == NULL)
                {
                    customTaskJSON = @"{\"tasks\":[]}";
                }
                
                NSData * jsonData = [customTaskJSON dataUsingEncoding:NSUTF8StringEncoding];
                NSError * jsonError = NULL;
                NSMutableDictionary * jsonDictionary = [[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError] mutableCopy];

                NSMutableArray * tasksArray = [[jsonDictionary objectForKey:@"tasks"] mutableCopy];
                if (tasksArray != NULL)
                {
                    NSInteger existingTasksArrayCount = tasksArray.count;
                    
                    if (pathTableSelectedRow < existingTasksArrayCount)
                    {
                        [tasksArray removeObjectAtIndex:pathTableSelectedRow];
                        
                        [jsonDictionary setObject:tasksArray forKey:@"tasks"];
                        
                        NSError * newJSONError = NULL;
                        NSData * newJSONData = [NSJSONSerialization dataWithJSONObject:jsonDictionary options:0 error:&newJSONError];
                        NSString * newJSONString = [[NSString alloc] initWithData:newJSONData encoding:NSUTF8StringEncoding];
                        
                        [customTaskDictionary setObject:newJSONString forKey:@"task_json"];

                        [self.allCustomTasksArray replaceObjectAtIndex:nameTableSelectedRow withObject:customTaskDictionary];
                        
                        [self.sqliteController updateCustomTaskRecordForID:taskIDString name:taskName json:newJSONString sampleRate:sampleRate channels:channels];

                        self.allCustomTasksArray = [[self.sqliteController allCustomTaskRecords] mutableCopy];

                        [self getExistingSelections];
                        [self.nameTableView reloadData];
                        [self.pathTableView reloadData];
                        [self.argumentTableView reloadData];
                        [self reselectRecord];

                        if (pathTableSelectedRow > 0)
                        {
                            if (pathTableSelectedRow < tasksArray.count)
                            {
                                NSIndexSet * rowIndexes = [NSIndexSet indexSetWithIndex:pathTableSelectedRow];
                                [self.pathTableView selectRowIndexes:rowIndexes byExtendingSelection:NO];
                            }
                            else
                            {
                                if (tasksArray.count > 0)
                                {
                                    NSIndexSet * rowIndexes = [NSIndexSet indexSetWithIndex:tasksArray.count - 1];
                                    [self.pathTableView selectRowIndexes:rowIndexes byExtendingSelection:NO];
                                }
                                else
                                {
                                    [self.pathTableView deselectAll:self];
                                }
                            }
                        }
                        else
                        {
                            [self.pathTableView deselectAll:self];
                        }
                    }
                    else
                    {
                        NSBeep();
                    }
                }
                else
                {
                    NSBeep();
                }
            }
            else
            {
                NSBeep();
            }
        }
        else
        {
            NSBeep();
        }
    }
    else
    {
        NSBeep();
    }
}



- (IBAction)addArgument:(id)sender
{
    NSInteger selectedCustomTaskRow = self.nameTableView.selectedRow;
    NSInteger selectedPathRow = self.pathTableView.selectedRow;
    NSInteger selectedArgumentsRow = self.argumentTableView.selectedRow;

    NSInteger newSelectedArgumentsRow = -1;
    
    if ((selectedCustomTaskRow >= 0) &&
            (selectedPathRow >= 0) &&
            (selectedCustomTaskRow < self.allCustomTasksArray.count))
    {
        NSMutableDictionary * customTaskDictionary = [[self.allCustomTasksArray objectAtIndex:selectedCustomTaskRow] mutableCopy];
        
        NSNumber * taskIDNumber = [customTaskDictionary objectForKey:@"id"];
        NSString * taskIDString = taskIDNumber.stringValue;
        
        NSString * taskName = [customTaskDictionary objectForKey:@"task_name"];
        
        NSNumber * sampleRateNumber = [customTaskDictionary objectForKey:@"sample_rate"];
        NSInteger sampleRate = sampleRateNumber.integerValue;
        
        NSNumber * channelsNumber = [customTaskDictionary objectForKey:@"channels"];
        NSInteger channels = channelsNumber.integerValue;

        NSString * customTaskJSON = [[customTaskDictionary objectForKey:@"task_json"] mutableCopy];
        if (customTaskJSON != NULL)
        {
            NSData * jsonData = [customTaskJSON dataUsingEncoding:NSUTF8StringEncoding];
            NSError * jsonError = NULL;
            NSMutableDictionary * jsonDictionary = [[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError] mutableCopy];

            NSMutableArray * tasksArray = [[jsonDictionary objectForKey:@"tasks"] mutableCopy];
            if (tasksArray != NULL)
            {
                NSInteger tasksArrayCount = tasksArray.count;
                
                if ((tasksArrayCount > 0) && (selectedPathRow < tasksArrayCount))
                {
                    NSMutableDictionary * selectedTaskDictionary = [[tasksArray objectAtIndex:selectedPathRow] mutableCopy];
                    
                    NSMutableArray * argumentsArray = [[selectedTaskDictionary objectForKey:@"arguments"] mutableCopy];
                    if (argumentsArray != NULL)
                    {
                        if ((selectedArgumentsRow >= 0) && (selectedArgumentsRow < argumentsArray.count))
                        {
                            NSString * emptyString = [NSString string];
                            [argumentsArray insertObject:emptyString atIndex:selectedArgumentsRow + 1];
                            newSelectedArgumentsRow = selectedArgumentsRow + 1;
                        }
                        else
                        {
                            NSString * emptyString = [NSString string];
                            [argumentsArray addObject:emptyString];
                            newSelectedArgumentsRow = argumentsArray.count - 1;
                        }

                        [selectedTaskDictionary setObject:argumentsArray forKey:@"arguments"];
                        [tasksArray replaceObjectAtIndex:selectedPathRow withObject:selectedTaskDictionary];
                        [jsonDictionary setObject:tasksArray forKey:@"tasks"];
                        
                        NSError * newJSONError = NULL;
                        NSData * newJSONData = [NSJSONSerialization dataWithJSONObject:jsonDictionary options:0 error:&newJSONError];
                        NSString * newJSONString = [[NSString alloc] initWithData:newJSONData encoding:NSUTF8StringEncoding];
                        
                        [customTaskDictionary setObject:newJSONString forKey:@"task_json"];

                        [self.allCustomTasksArray replaceObjectAtIndex:selectedCustomTaskRow withObject:customTaskDictionary];
                        
                        [self.sqliteController updateCustomTaskRecordForID:taskIDString name:taskName json:newJSONString sampleRate:sampleRate channels:channels];
    
                        self.allCustomTasksArray = [[self.sqliteController allCustomTaskRecords] mutableCopy];

                        [self getExistingSelections];
                        [self.nameTableView reloadData];
                        [self.pathTableView reloadData];
                        [self.argumentTableView reloadData];
                        [self reselectRecord];

                        NSIndexSet * pathRowIndexes = [NSIndexSet indexSetWithIndex:selectedPathRow];
                        [self.pathTableView selectRowIndexes:pathRowIndexes byExtendingSelection:NO];

                        if (newSelectedArgumentsRow > -1)
                        {
                            NSIndexSet * argumentRowIndexes = [NSIndexSet indexSetWithIndex:newSelectedArgumentsRow];
                            [self.argumentTableView selectRowIndexes:argumentRowIndexes byExtendingSelection:NO];
                        }
                    }
                }
                else
                {
                    NSBeep();
                }
            }
            else
            {
                NSBeep();
            }
        }
        else
        {
            NSBeep();
        }
    }
    else
    {
        NSBeep();
    }
}


- (IBAction)deleteArgument:(id)sender
{
    NSInteger selectedCustomTaskRow = self.nameTableView.selectedRow;
    NSInteger selectedPathRow = self.pathTableView.selectedRow;
    NSInteger selectedArgumentsRow = self.argumentTableView.selectedRow;

    NSInteger newSelectedArgumentsRow = -1;
    
    if ((selectedCustomTaskRow >= 0) &&
            (selectedPathRow >= 0) &&
            (selectedCustomTaskRow < self.allCustomTasksArray.count))
    {
        NSMutableDictionary * customTaskDictionary = [[self.allCustomTasksArray objectAtIndex:selectedCustomTaskRow] mutableCopy];
        
        NSNumber * taskIDNumber = [customTaskDictionary objectForKey:@"id"];
        NSString * taskIDString = taskIDNumber.stringValue;
        
        NSString * taskName = [customTaskDictionary objectForKey:@"task_name"];
        
        NSNumber * sampleRateNumber = [customTaskDictionary objectForKey:@"sample_rate"];
        NSInteger sampleRate = sampleRateNumber.integerValue;
        
        NSNumber * channelsNumber = [customTaskDictionary objectForKey:@"channels"];
        NSInteger channels = channelsNumber.integerValue;

        NSString * customTaskJSON = [[customTaskDictionary objectForKey:@"task_json"] mutableCopy];
        if (customTaskJSON != NULL)
        {
            NSData * jsonData = [customTaskJSON dataUsingEncoding:NSUTF8StringEncoding];
            NSError * jsonError = NULL;
            NSMutableDictionary * jsonDictionary = [[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError] mutableCopy];

            NSMutableArray * tasksArray = [[jsonDictionary objectForKey:@"tasks"] mutableCopy];
            if (tasksArray != NULL)
            {
                NSInteger tasksArrayCount = tasksArray.count;
                
                if ((tasksArrayCount > 0) && (selectedPathRow < tasksArrayCount))
                {
                    NSMutableDictionary * selectedTaskDictionary = [[tasksArray objectAtIndex:selectedPathRow] mutableCopy];
                    
                    NSMutableArray * argumentsArray = [[selectedTaskDictionary objectForKey:@"arguments"] mutableCopy];
                    if (argumentsArray != NULL)
                    {
                        if ((selectedArgumentsRow >= 0) && (selectedArgumentsRow < argumentsArray.count))
                        {
                            NSString * emptyString = [NSString string];
                            [argumentsArray removeObjectAtIndex:selectedArgumentsRow];
                            
                            if (selectedArgumentsRow < argumentsArray.count)
                            {
                                newSelectedArgumentsRow = selectedArgumentsRow;
                            }
                            else
                            {
                                newSelectedArgumentsRow = argumentsArray.count - 1;
                            }

                            [selectedTaskDictionary setObject:argumentsArray forKey:@"arguments"];
                            [tasksArray replaceObjectAtIndex:selectedPathRow withObject:selectedTaskDictionary];
                            [jsonDictionary setObject:tasksArray forKey:@"tasks"];
                        
                            NSError * newJSONError = NULL;
                            NSData * newJSONData = [NSJSONSerialization dataWithJSONObject:jsonDictionary options:0 error:&newJSONError];
                            NSString * newJSONString = [[NSString alloc] initWithData:newJSONData encoding:NSUTF8StringEncoding];
                        
                            [customTaskDictionary setObject:newJSONString forKey:@"task_json"];

                            [self.allCustomTasksArray replaceObjectAtIndex:selectedCustomTaskRow withObject:customTaskDictionary];
                        
                            [self.sqliteController updateCustomTaskRecordForID:taskIDString name:taskName json:newJSONString sampleRate:sampleRate channels:channels];
        
                            self.allCustomTasksArray = [[self.sqliteController allCustomTaskRecords] mutableCopy];

                            [self getExistingSelections];
                            [self.nameTableView reloadData];
                            [self.pathTableView reloadData];
                            [self.argumentTableView reloadData];
                            [self reselectRecord];

                            NSIndexSet * pathRowIndexes = [NSIndexSet indexSetWithIndex:selectedPathRow];
                            [self.pathTableView selectRowIndexes:pathRowIndexes byExtendingSelection:NO];

                            if (newSelectedArgumentsRow > -1)
                            {
                                NSIndexSet * argumentRowIndexes = [NSIndexSet indexSetWithIndex:newSelectedArgumentsRow];
                                [self.argumentTableView selectRowIndexes:argumentRowIndexes byExtendingSelection:NO];
                            }
                        }
                        else
                        {
                            NSBeep();
                        }
                    }
                }
                else
                {
                    NSBeep();
                }
            }
            else
            {
                NSBeep();
            }
        }
        else
        {
            NSBeep();
        }
    }
    else
    {
        NSBeep();
    }
}


- (void)getExistingSelections
{
    self.previousNameTableSelectedRow = self.nameTableView.selectedRow;
    if (self.previousNameTableSelectedRow >= 0)
    {
        if (self.previousNameTableSelectedRow >= self.allCustomTasksArray.count)
        {
            self.previousNameTableSelectedRow = self.allCustomTasksArray.count - 1;
        }
    
        NSDictionary * previousSelectedCustomTaskDictionary = [self.allCustomTasksArray objectAtIndex:self.previousNameTableSelectedRow];
        NSNumber * taskIDNumber = [previousSelectedCustomTaskDictionary objectForKey:@"id"];
        self.previousSelectedCustomTaskID = taskIDNumber.stringValue;
    }
    else
    {
        self.previousSelectedCustomTaskID = NULL;
    }

    self.previousPathTableSelectedRow = self.pathTableView.selectedRow;

    self.previousArgumentsTableSelectedRow = self.pathTableView.selectedRow;
}



- (void)reselectRecord
{
    if (self.previousSelectedCustomTaskID != NULL)
    {
        for (NSDictionary * aCustomTaskDictionary in self.allCustomTasksArray)
        {
            NSNumber * taskIDNumber = [aCustomTaskDictionary objectForKey:@"id"];
            NSString * taskID = taskIDNumber.stringValue;
            if ([taskID isEqualToString:self.previousSelectedCustomTaskID] == YES)
            {
                NSInteger newRowIndex = [self.allCustomTasksArray indexOfObject:aCustomTaskDictionary];
                NSIndexSet * rowIndexes = [NSIndexSet indexSetWithIndex:newRowIndex];
                [self.nameTableView selectRowIndexes:rowIndexes byExtendingSelection:NO];

                self.previousSelectedCustomTaskID = NULL;
                self.previousNameTableSelectedRow = -1;
                self.previousPathTableSelectedRow = -1;
                self.previousArgumentsTableSelectedRow = -1;

                break;
            }
        }
    }
}


@end

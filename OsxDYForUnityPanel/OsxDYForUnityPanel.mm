//
//  OsxDYForUnityPanel.mm
//  OsxDYForUnityPanel
//korewang2011@gmail.com
//  Created by wangxy on 2022/9/14.
//

#import "OsxDYForUnityPanel.pch"



static callbackFunc asyncCallBack;
const char* OsxOpenFilesDialog(const char* title,
                                const char* directory,
                                const char* filters,
                                bool multiselect) {
    ImpOSXOpenFile* panel = [[ImpOSXOpenFile alloc] init];
    NSString* paths = [panel dialogFileFilterPanel:[NSString stringWithUTF8String:title ?: ""]
                                        directory:[NSString stringWithUTF8String:directory ?: ""]
                                          filters:[NSString stringWithUTF8String:filters ?: ""]
                                      multiselect:multiselect
                                   canChooseFiles:YES
                                 canChooseFolders:NO];
    return [paths UTF8String];
}

void OsxOpenFilePanelAsyncCallback(const char* title,
                              const char* directory,
                              const char* filters,
                              bool multiselect,
                              callbackFunc cb) {
    asyncCallBack = cb;
    ImpOSXOpenFile* dialog = [[ImpOSXOpenFile alloc] init];
    [dialog dialogFileFilterPanelAsyncCall:[NSString stringWithUTF8String:title ?: ""]
                           directory:[NSString stringWithUTF8String:directory ?: ""]
                             filters:[NSString stringWithUTF8String:filters ?: ""]
                         multiselect:multiselect
                      canChooseFiles:YES
                    canChooseFolders:NO];
}


@implementation ImpOSXOpenFile

- (id)init {
    if (self = [super init]) {
        NSLog(@"init");
    }
    return self;
}

// one
- (NSString*)dialogFileFilterPanel:(NSString*)title
                       directory:(NSString*)directory
                         filters:(NSString*)filters
                     multiselect:(BOOL)multiselect
                  canChooseFiles:(BOOL)canChooseFiles
                canChooseFolders:(BOOL)canChooseFolders {

    NSOpenPanel* panel = [self createOpenPanel:title
                                     directory:directory
                                       filters:filters
                                   multiselect:multiselect
                                canChooseFiles:canChooseFiles
                              canChooseFolders:canChooseFolders];
    if (panel && [panel runModal] == NSModalResponseOK && [[panel URLs] count] > 0) {
        NSMutableArray* paths = [NSMutableArray arrayWithCapacity:[[panel URLs] count]];
        for (int i = 0; i < [[panel URLs] count]; i++) {
            NSURL* url = [[panel URLs] objectAtIndex:i];
            [paths addObject:[url path]];
        }
        NSString* seperator = [NSString stringWithFormat:@"%c", 28];
        return [paths componentsJoinedByString:seperator];
    }
    return @"";
}
// call
- (void)dialogFileFilterPanelAsyncCall:(NSString*)title
                       directory:(NSString*)directory
                         filters:(NSString*)filters
                     multiselect:(BOOL)multiselect
                  canChooseFiles:(BOOL)canChooseFiles
                canChooseFolders:(BOOL)canChooseFolders {

    NSOpenPanel* panel = [self createOpenPanel:title
                                     directory:directory
                                       filters:filters
                                   multiselect:multiselect
                                canChooseFiles:canChooseFiles
                              canChooseFolders:canChooseFolders];
    [self performSelectorOnMainThread:@selector(dialogFileAsyncSelector:) withObject:panel waitUntilDone:NO];
}
- (void)dialogFileAsyncSelector:(NSOpenPanel*)panel {
    NSString* pathsStr = @"";
    if (panel && [panel runModal] == NSModalResponseOK && [[panel URLs] count] > 0) {
        NSMutableArray* paths = [NSMutableArray arrayWithCapacity:[[panel URLs] count]];
        for (int i = 0; i < [[panel URLs] count]; i++) {
            NSURL* url = [[panel URLs] objectAtIndex:i];
            [paths addObject:[url path]];
        }
        NSString* seperator = [NSString stringWithFormat:@"%c", 28];
        pathsStr = [paths componentsJoinedByString:seperator];
    }
    asyncCallBack([pathsStr UTF8String]);
}


- (NSOpenPanel*)createOpenPanel:(NSString*)title
                      directory:(NSString*)directory
                        filters:(NSString*)filters
                    multiselect:(BOOL)multiselect
                 canChooseFiles:(BOOL)canChooseFiles
               canChooseFolders:(BOOL)canChooseFolders {
    @try {
        NSMutableArray* filterItems = [[NSMutableArray alloc] init];
        NSMutableArray* extensions = [[NSMutableArray alloc] init];
        [self parseFilter:filters filters:filterItems extensions:extensions];

        NSOpenPanel* panel = [NSOpenPanel openPanel];

        if (filterItems.count > 0) {
            PopUpButtonHandler* popUpHandler = [[PopUpButtonHandler alloc] initWithPanel:panel];
            [popUpHandler setExtensions:extensions];

            NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 200, 24.0)];
            NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 60, 22)];
            [label setEditable:NO];
            [label setStringValue:@"File type:"];
            [label setBordered:NO];
            [label setBezeled:NO];
            [label setDrawsBackground:NO];

            NSPopUpButton *popupButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(61.0, 2, 140, 22.0) pullsDown:NO];
            [popupButton addItemsWithTitles:filterItems];
            [popupButton setTarget:popUpHandler];
            [popupButton setAction:@selector(selectFormatOpen:)];

            [accessoryView addSubview:label];
            [accessoryView addSubview:popupButton];

            [panel setAccessoryView:accessoryView];
            if ([panel respondsToSelector:@selector(setAccessoryViewDisclosed:)]) {
                [panel setAccessoryViewDisclosed:YES];
            }
            [panel setAllowedFileTypes:(NSArray*)[extensions objectAtIndex:0]];
        }

        if ([title length] != 0) {
            [panel setMessage:title];
        }
        [panel setCanChooseFiles:canChooseFiles];
        [panel setCanChooseDirectories:canChooseFolders];
        [panel setAllowsMultipleSelection:multiselect];
        [panel setDirectoryURL:[NSURL fileURLWithPath:directory]];
        if ([panel respondsToSelector:@selector(setCanCreateDirectories:)]) {
            [panel setCanCreateDirectories:YES];
        }

        return panel;
    }
    @catch (NSException *exception) {
        NSLog(@"OSX::createOpenPanel Exception: %@", exception.reason);
        return nil;
    }
}



- (void)parseFilter:(NSString*)filter filters:(NSMutableArray*)filters extensions:(NSMutableArray*)extensions {
    if ([filter length] == 0) {
        return;
    }

    @try {
        NSArray* fileFilters = [filter componentsSeparatedByString:@"|"];
        for (NSString* filter in fileFilters) {
            NSArray* f = [filter componentsSeparatedByString:@";"];
            NSString* filterName = (NSString*)[f objectAtIndex:0];

            NSString* extNames = (NSString*)[f objectAtIndex:1];
            NSArray* exts = [extNames componentsSeparatedByString:@","];

            NSMutableString* filterItemName = [[NSMutableString alloc] init];
            [filterItemName appendFormat:@"%@ (", filterName];
            for (NSString* ext in exts) {
                [filterItemName appendFormat:@"*.%@,", ext];
            }
            [filterItemName deleteCharactersInRange:NSMakeRange([filterItemName length]-1, 1)];
            [filterItemName appendString:@")"];

            [filters addObject:filterItemName];
            [extensions addObject:exts];
        }
    } @catch (NSException *exception) {
        NSLog(@"Osx::parseFilter list Exception%@", exception.reason);
    }
}

@end

@implementation PopUpButtonHandler

- (id)initWithPanel:(NSPanel*)panel {
    self = [super init];
    if (self) {
        _panel = panel;
    }
    return self;
}

- (void)setExtensions:(NSArray *)extensions {
    _extensions = extensions;
}

- (void)selectFormatOpen:(id)sender {
    NSPopUpButton* button = (NSPopUpButton *)sender;
    NSInteger selectedItemIndex = [button indexOfSelectedItem];

    NSString* firstExtension = (NSString*)[[_extensions objectAtIndex:selectedItemIndex] objectAtIndex:0];
    if ([firstExtension isEqualToString:@""] || [firstExtension isEqualToString:@"*"]) {
        [((NSOpenPanel*)_panel) setAllowedFileTypes:nil];
    }
    else {
        [((NSOpenPanel*)_panel) setAllowedFileTypes:[_extensions objectAtIndex:selectedItemIndex]];
    }
    [((NSSavePanel*)_panel) update];
}

- (void)selectFormatSave:(id)sender {
    NSPopUpButton* button = (NSPopUpButton *)sender;
    NSInteger selectedItemIndex = [button indexOfSelectedItem];
    NSString* nameFieldString = [((NSSavePanel*)_panel) nameFieldStringValue];
    NSString* trimmedNameFieldString = [nameFieldString stringByDeletingPathExtension];

    NSString* ext = [[_extensions objectAtIndex:selectedItemIndex] objectAtIndex:0];
    NSString* nameFieldStringWithExt = nil;

    if ([ext isEqualToString:@""] || [ext isEqualToString:@"*"]) {
        nameFieldStringWithExt = trimmedNameFieldString;
        [((NSSavePanel*)_panel) setAllowedFileTypes:nil];
    }
    else {
        nameFieldStringWithExt = [NSString stringWithFormat:@"%@.%@", trimmedNameFieldString, ext];
        [((NSSavePanel*)_panel) setAllowedFileTypes:@[ext]];
    }
    
    [((NSSavePanel*)_panel) setNameFieldStringValue:nameFieldStringWithExt];
    [((NSSavePanel*)_panel) update];
}

@end

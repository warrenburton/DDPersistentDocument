//
//  DDDocument.m
//
//  Created by Warren Burton on 06/05/2013.
//  WTFPL Licensed
// ----------------
// Use at your own risk. Modify and redistribute freely
//

#import "DDPersistentDocument.h"

static NSString *StoreDirectoryName = @"StoreContent";

static NSString *StoreFileName = @"persistentStore";

@interface DDPersistentDocument () {
    
    NSPersistentStoreCoordinator *_persistentStoreCoordinator;
    
    NSPersistentStore *_persistentStore;
    
    NSManagedObjectContext *_mainContext;
    
    NSManagedObjectModel *_managedObjectModel;
    
    NSURL *_persistentStoreURL;
    
}


@end

@implementation DDPersistentDocument


+ (BOOL)autosavesInPlace
{
    return YES;
}


- (void)setFileURL:(NSURL *)fileURL {
	
    DLog(@"set file url %@",fileURL)
    NSURL *originalFileURL = [self storeURLForFileAtURL:self.fileURL];
    if (originalFileURL != nil) {
        NSPersistentStoreCoordinator *psc = [[self managedObjectContext] persistentStoreCoordinator];
        NSPersistentStore *store = [psc persistentStoreForURL:originalFileURL];
        
        if (store != nil) {
            DLog(@"**** and reconfigure %@",fileURL)
            [psc setURL:[self storeURLForFileAtURL:fileURL] forPersistentStore:store];
        }
    }
       
    [super setFileURL:fileURL];
}


- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)error {
	
    BOOL success = [self configurePersistentStoreCoordinatorForURL:[self storeURLForFileAtURL:absoluteURL] error:error];

    return success;
}

- (BOOL)writeSafelyToURL:(NSURL *)inAbsoluteURL ofType:(NSString *)inTypeName forSaveOperation:(NSSaveOperationType)inSaveOperation error:(NSError **)outError {
	
    BOOL success = YES;
    
    NSURL *originalURL = [self fileURL];
    
    //DLog(@"save op is %ld",inSaveOperation);
	
    if (inSaveOperation == NSAutosaveElsewhereOperation || inSaveOperation == NSSaveAsOperation) {
		
        
        NSURL *storeURL = [self storeURLForFileAtURL:inAbsoluteURL];
      
        NSURL *originalStoreURL = [self storeURLForFileAtURL:originalURL];
        
        NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
        
        NSPersistentStore *originalStore = nil;
		
        if (originalStoreURL != nil) {
            
            originalStore = [coordinator persistentStoreForURL:originalStoreURL];

        }
		else {
            //we can assume that there is zero or one
            NSArray *stores = coordinator.persistentStores;
            
            originalStore = [stores lastObject];
            
        }
        
        if (originalStore) {
            success = ([coordinator migratePersistentStore:originalStore toURL:storeURL options:nil withType:NSSQLiteStoreType error:outError] != nil);
        }
        else {
            success = NO;
        }
        
    }
    else if (inSaveOperation == NSAutosaveAsOperation)
    {
        NSURL *storeURL = [self storeURLForFileAtURL:inAbsoluteURL];
        success = [self configurePersistentStoreCoordinatorForURL:storeURL error:outError];
        if (!success) {
            
            DLog(@"failed to create new - %@:%ld",[*outError localizedDescription],(long)[*outError code]);
            
        }
    }
	
    
    
    if (success == YES) {
        // Save the Core Data portion of the document.
        success = [[self managedObjectContext] save:outError];
        if (!success) {
            
            DLog(@"failed to save MOC - %@:%ld",[*outError localizedDescription],(long)[*outError code]);

            
        }
    }
    
    if (success == YES) {
        // Set the appropriate file attributes (such as "Hide File Extension")
        NSDictionary *fileAttributes = [self fileAttributesToWriteToURL:inAbsoluteURL ofType:inTypeName forSaveOperation:inSaveOperation originalContentsURL:originalURL error:outError];
        [[NSFileManager defaultManager] setAttributes:fileAttributes ofItemAtPath:[inAbsoluteURL path] error:NULL];
    }
	
    return success;
}


- (BOOL)revertToContentsOfURL:(NSURL *)inAbsoluteURL ofType:(NSString *)inTypeName error:(NSError **)outError {

    NSPersistentStoreCoordinator *psc = [self persistentStoreCoordinator];
    
    NSPersistentStore *store = [psc persistentStoreForURL:[self storeURLForFileAtURL:inAbsoluteURL]];
    if (store) {
        
        [psc removePersistentStore:store error:outError];
        
    }
    return [super revertToContentsOfURL:inAbsoluteURL ofType:inTypeName error:outError];
}



#pragma mark Core Data Stack

-(BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)aurl error:(NSError **)error
{
    DLog(@"configuring - %@",aurl);
    
    NSMutableDictionary *opts = [NSMutableDictionary dictionaryWithCapacity:2];
    opts[NSInferMappingModelAutomaticallyOption] = @YES;
    opts[NSMigratePersistentStoresAutomaticallyOption] = @YES;
    
    NSRange seek = [[aurl absoluteString] rangeOfString:@"com.apple.documentVersions"];
    if (seek.location != NSNotFound) {
        
        DLog(@"this is a versions url - configure as RO")
        opts[NSReadOnlyPersistentStoreOption] = @YES;
    
    }
    
    NSError *aerror = nil;
    
    _persistentStore = [[self persistentStoreCoordinator] addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:aurl options:opts error:&aerror];
    
    if (!_persistentStore) {
        *error = aerror;
        return NO;
    }
    
    return YES;
}



-(NSURL *)storeURLForFileAtURL:(NSURL *)storeURL
{
    if (storeURL) {
        
        NSURL *tempurl = [storeURL  URLByAppendingPathComponent:StoreDirectoryName];
        
        NSError *error = NULL;
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:[tempurl path]]) {
            
            [[NSFileManager defaultManager] createDirectoryAtURL:tempurl withIntermediateDirectories:YES attributes:nil error:&error];
            
        }
        
        tempurl = [tempurl URLByAppendingPathComponent:StoreFileName];
        
        return tempurl;
    }
    
    return nil;
   
}



- (NSManagedObjectModel *)managedObjectModel {
	
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    
    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    
    return _managedObjectModel;
}


- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator == nil) {
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    }
    return _persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext {
    if (_mainContext == nil) {
        _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_mainContext setPersistentStoreCoordinator:[self persistentStoreCoordinator]];
        [self setUndoManager:[_mainContext undoManager]];
    }
    return _mainContext;
}



@end

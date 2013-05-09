DDPersisitentDocument
=====================

Lion/Mountain Lion support for wrappered core data such as documents created by UIManagedDocument

This subclass on NSDocument allows you to use the standard 10.7/10.8 Documents based app features of Duplicate/Autosave/Versions with Core Data 

The class is designed to read the wrappers produced by UIManagedDocument hence expects to find the persistent store in *FileName.foobar/StoreContent/persistentStore*

It also currently does NOT support **Ubiquitous** coredata. Any iCloud syncing done will be atomic style "Last man in wins" 


//
//  DLog.h
//  genealogical
//
//  Created by Warren Burton on 09/05/2013.
//  Copyright (c) 2013 Warren Burton. All rights reserved.
//


#ifdef DEBUG
#define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#define DLogRect(rect)  NSLog(@"%s [Line %d] (%f,%f %f,%f)", __PRETTY_FUNCTION__, __LINE__, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
#else
#define DLog(...)
#define DLogRect(rect)
#endif
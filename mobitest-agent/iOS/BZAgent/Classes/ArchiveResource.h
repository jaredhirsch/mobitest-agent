//
//  ArchiveResource.h
//  BZAgent
//
//  This file holds data deduced from runtime information, and us such
//  is NOT VERY RELIABLE. USE/CHANGE WITH CAUTION.
// 
//
//  Created by Guy Podjarny on 11-09-19.
//  Copyright (c) 2011 Blaze. All rights reserved.
//

#ifndef BZAgent_ArchiveResource_h
#define BZAgent_ArchiveResource_h


// This structure holds a pointer to a data buffer holding:
// The reference count and flags 
// The length of the string
// Other?
// (Total till now somehow is 20 bytes)
// The data itself (real data, char * style)
struct CString { 
    char *data;
};

static NSString *CString_getData(CString ptr)
{
    const unichar *val = (const unichar*)(ptr.data+20);
    size_t length = (size_t)*(ptr.data+4);
    NSString *nsstr = [NSString stringWithCharacters:val length:length];
    return nsstr;
}


struct KURL {
    CString m_string; 
    unsigned int m_isValid; 
    unsigned int m_protocolIsInHTTPFamily; 
    int m_schemeEnd; 
    int m_userStart; 
    int m_userEnd; 
    int m_passwordEnd; 
    int m_hostEnd; 
    int m_portEnd; 
    int m_pathAfterLastSlash; 
    int m_pathEnd; 
    int m_queryEnd; 
    //int m_fragmentEnd; 
};

struct HTTPHeaderMap { 
    struct HashTable_BLA_BLA { 
        struct pair_WTF_AtomicString_WTF_String {} *m_table; 
        int m_tableSize; 
        int m_tableSizeMask; 
        int m_keyCount; 
        int m_deletedCount; 
    } m_impl; 
};

struct ResourceResponse { 
    struct KURL m_url; 
    CString m_mimeType; 
    long long m_expectedContentLength; 
    CString m_textEncodingName; 
    CString m_suggestedFilename; 
    int m_httpStatusCode; 
    CString m_httpStatusText; 
    struct HTTPHeaderMap m_httpHeaderFields; 
    int m_lastModifiedDate; 
    unsigned int m_wasCached : 1; 
    unsigned int m_connectionID; 
    unsigned int m_connectionReused : 1; 
    struct RefPtr_WebCore_ResourceLoadTiming { 
        struct ResourceLoadTiming {} *m_ptr; 
    } m_resourceLoadTiming; 
    struct RefPtr_WebCore_ResourceLoadInfo { 
        struct ResourceLoadInfo {} *m_ptr; 
    } m_resourceLoadInfo; 
    unsigned int m_isNull : 1; 
    unsigned int m_haveParsedCacheControlHeader : 1; 
    unsigned int m_haveParsedAgeHeader : 1; 
    unsigned int m_haveParsedDateHeader : 1; 
    unsigned int m_haveParsedExpiresHeader : 1; 
    unsigned int m_haveParsedLastModifiedHeader : 1; 
    unsigned int m_cacheControlContainsNoCache : 1; 
    unsigned int m_cacheControlContainsNoStore : 1; 
    unsigned int m_cacheControlContainsMustRevalidate : 1; 
    double m_cacheControlMaxAge; 
    double m_age; 
    double m_date; 
    double m_expires; 
    double m_lastModified; 
    struct RetainPtr__CFURLResponsePtr { 
        struct _CFURLResponse {} *m_ptr; 
    } m_cfResponse; 
    struct RetainPtr_NSURLResponse_ { 
        NSURLResponse *m_ptr; 
    } m_nsResponse; 
    int m_initLevel; 
};

struct ArchiveResource 
{
    int (**x1)();
    int x2; 
    struct KURL url;
    struct ResourceResponse resResp; 
    struct RefPtr_WebCore_SharedBuffer { 
        struct SharedBuffer {} *m_ptr; 
    } x5; 
    CString x6; 
    CString x7; 
    CString x8; 
    bool x9;
};



#endif

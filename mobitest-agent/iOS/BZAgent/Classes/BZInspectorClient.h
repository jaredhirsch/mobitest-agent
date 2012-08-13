//This code is unused.  It relies on libraries deep within WebCore.

///*
// *  BZInspectorClient.h
// *  BZAgent
// *
// *  Created by Joshua Tessier on 10-11-30.
// *
// */
//
//#ifndef BZInspectorClient_h
//#define BZInspectorClient_h
//
//#include "InspectorClient.h"
//
//namespace WebCore {
//	class WebInspectorFrontendClient {};
//	
//class BZInspectorClient : public WebInspectorFrontendClient {
//public:
//	~BZInspectorClient() {}
//	
//	virtual void inspectorDestroyed();
//	
//    virtual void openInspectorFrontend(InspectorController*);
//	
//    virtual void highlight(Node*);
//    virtual void hideHighlight();
//	
//    virtual void populateSetting(const String& key, String* value);
//    virtual void storeSetting(const String& key, const String& value);
//	
//    virtual bool sendMessageToFrontend(const String& message);
//	
//    // Navigation can cause some WebKit implementations to change the view / page / inspector controller instance.
//    // However, there are some inspector controller states that should survive navigation (such as tracking resources
//    // or recording timeline). Following callbacks allow embedders to track these states.
//    virtual void updateInspectorStateCookie(const String&);
//	
//    bool doDispatchMessageOnFrontendPage(Page* frontendPage, const String& message);
//};
//	
//}
//
//#endif //BZInspectorClient_h
//
//  InAppPurchaseANE.m
//  InAppPurchaseANE
//
//  Created by Antoine Kleinpeter on 30/10/14.
//  Copyright (c) 2014 studiopixmix. All rights reserved.
//
#import "FlashRuntimeExtensions.h"
#import "TypeConversionHelper.h"
#import "ExtensionDefs.h"
#import <StoreKit/StoreKit.h>
#import "ProductsRequestDelegate.h"
#import "TransactionObserver.h"

#define DEFINE_ANE_FUNCTION(fn) FREObject (fn)(FREContext context, void* functionData, uint32_t argc, FREObject argv[])

#define MAP_FUNCTION(fn, data) { (const uint8_t*)(#fn), (data), &(fn) }
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)


TypeConversionHelper* typeConversionHelper;
ProductsRequestDelegate *productsRequestDelegate;
TransactionObserver *transactionObserver;

DEFINE_ANE_FUNCTION(initialize) {
    transactionObserver.context = context;
    [[SKPaymentQueue defaultQueue] addTransactionObserver:transactionObserver];
    
    DISPATCH_LOG_EVENT(context, @"In app purchase ANE initialized on iOS.");
    return NULL;
}

DEFINE_ANE_FUNCTION(getProducts) {
    NSArray *productIdsRequested = [typeConversionHelper FREGetObjectAsStringArray:argv[0]];
    
    NSString *logMessage = [NSString stringWithFormat:@"Starting an SKProductsRequest with products %@", [productIdsRequested componentsJoinedByString:@", "]];
    DISPATCH_LOG_EVENT(context, logMessage);
    
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIdsRequested]];
    
    productsRequestDelegate.context = context;
    productsRequest.delegate = productsRequestDelegate;
    
    [productsRequest start];
    
    return NULL;
}

DEFINE_ANE_FUNCTION(buyProduct) {
    NSString *productId;
    if ([typeConversionHelper FREGetObject:argv[0] asString:&productId] != FRE_OK) {
        DISPATCH_ANE_EVENT(context, EVENT_PURCHASE_FAILURE, (uint8_t*)"No productId provided");
        return NULL;
    }
    
    NSString *logMessage = [NSString stringWithFormat:@"Buying product %@", productId];
    DISPATCH_LOG_EVENT(context, logMessage);
  
    SKProduct *product = [productsRequestDelegate getProductWithId:productId];
    
    if (product == nil) {
        DISPATCH_ANE_EVENT(context, EVENT_PURCHASE_FAILURE, (uint8_t*)"Product was not loaded with getProducts, cannot buy it");
        return NULL;
    }
    
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    payment.quantity = 1;
    
    DISPATCH_LOG_EVENT(context, @"Adding SKPayment to the SKPaymentQueue...");
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
    return NULL;
}

DEFINE_ANE_FUNCTION(restorePurchase) {
    
    DISPATCH_LOG_EVENT(context, @"Restoring the previous purchases ...");
    transactionObserver.context = context;
    [[SKPaymentQueue defaultQueue] addTransactionObserver:transactionObserver];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    
    return NULL;
}

void InAppPurchaseIosExtensionContextInitializer( void* extData, const uint8_t* ctxType, FREContext ctx, uint32_t* numFunctionsToSet, const FRENamedFunction** functionsToSet )
{
    static FRENamedFunction mopubFunctionMap[] =
    {
        MAP_FUNCTION(initialize, NULL),
        MAP_FUNCTION(getProducts, NULL),
        MAP_FUNCTION(buyProduct, NULL),
        MAP_FUNCTION(restorePurchase, NULL)
    };
        
    *numFunctionsToSet = sizeof( mopubFunctionMap ) / sizeof( FRENamedFunction );
    *functionsToSet = mopubFunctionMap;
}

void InAppPurchaseIosExtensionContextFinalizer( FREContext ctx )
{
	return;
}

void InAppPurchaseIosExtensionInitializer( void** extDataToSet, FREContextInitializer* ctxInitializerToSet, FREContextFinalizer* ctxFinalizerToSet )
{
    extDataToSet = NULL;
    *ctxInitializerToSet = &InAppPurchaseIosExtensionContextInitializer;
    *ctxFinalizerToSet = &InAppPurchaseIosExtensionContextFinalizer;
    
    typeConversionHelper = [[TypeConversionHelper alloc] init];
    productsRequestDelegate = [[ProductsRequestDelegate alloc] init];
    transactionObserver = [[TransactionObserver alloc] init];
}

void InAppPurchaseIosExtensionFinalizer()
{
    return;
}

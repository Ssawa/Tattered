#include "ofApp.h"

// The image we will actually be manipulating
/**
 This whole application should really be a more traditional iOS app, with
 a delegate being triggered with a view controller etc.. so that a user
 can upload their own photo from their photo album, but this is more of 
 a proof-of-concept
**/
ofImage baseImage;

// The UV plane for the image
ofPlanePrimitive imagePlane;

// Texture to be used to generate random values within shaders
ofImage noise;

// The shader responsible for randomly growing the burning area
ofShader fireSpreadShader;

// This shader has the simple task of turning green texels
// to RED and RED texels to blue
ofShader fireCoolShader;

// This is the shader that actually applies the fire texture to the photo
ofShader burnShader;

// Do some simple pinch and pull effects just for fun
ofShader pinchShader;

// Make sure texture maps correctly
ofShader mapper;

ofFbo fireBuffer1;
ofFbo fireBuffer2;

// The final fire texture
ofFbo fireTexture;

// User interaction variables
bool singletouch = false;
bool twoTouch = false;
bool moved = false;

// for one finger touches
float cX;
float cY;

// for two finger touches
float cX1Start;
float cY1Start;
float cX2Start;
float cY2Start;

float cX1Current;
float cY1Current;
float cX2Current;
float cY2Current;

ofVec2f midPoint;
float pullForce;

void scaleImageToFit(ofImage* image) {
    // The picture is in portrait and we should determain the scale ratio based on this
    if(image->height > image->width) {
        double scaleRatio = (double) ofGetScreenHeight() / image->height;
        image->resize(image->width * scaleRatio, ofGetScreenHeight());
    } else {
        // Otherwise, we are in landscape (or technically, a perfect square, in which case it shouldn't
        // matter) so we scale based on the width
        double scaleRatio = ofGetScreenWidth() / image->width;
        image->resize(ofGetScreenWidth(), image->height * scaleRatio);
    }
}

void generateFireTexture() {
    fireBuffer1.begin();
    
    // Draw the previous texure we generate so the fire
    // will actually grow
    mapper.begin();
    fireTexture.draw(0, 0);
    mapper.end();
    
    if (singletouch) {
        ofSetColor(255, 0, 0);
        ofCircle(cX, cY, 10);
    }
    fireBuffer1.end();
    
    /**
     The general proccess I'll be trying to follow
     for generating the burn shader is:
     * User drawn areas are classified as burning (RED)
     * RED texels can spread, and are inserted as GREEN
     * RED texels turn BLUE (Totally burnt) and don't spread
     * GREEN texels turn RED, and can cary on the burn until
     all are extinguished
     **/
    // This shader spread the burning (texels ajacent to RED texels might become green)
    fireSpreadShader.begin();
    fireSpreadShader.setUniform2f("texSize", fireBuffer1.getHeight(), fireBuffer1.getHeight());
    fireSpreadShader.setUniformTexture("noiseTex", noise.getTextureReference(), 1);
    
    // Draw this into the second buffer so we can do a second shader pass
    fireBuffer2.begin();
    fireBuffer1.draw(0, 0);
    fireBuffer2.end();
    fireSpreadShader.end();
    
    // The second pass
    fireCoolShader.begin();
    fireTexture.begin();
    fireBuffer2.draw(0, 0);
    fireTexture.end();
    fireCoolShader.end();
}

//--------------------------------------------------------------
void ofApp::setup(){
    ofBackground(0);
    
    baseImage.loadImage("stock-photo.jpg");
    scaleImageToFit(&baseImage);
    imagePlane.set(ofGetWidth(), ofGetHeight(), 50, 50);
    
    imagePlane.mapTexCoordsFromTexture(baseImage.getTextureReference());
    
    fireSpreadShader.load("Shaders/fireSpread");
    fireCoolShader.load("Shaders/fireCool");
    burnShader.load("burn");
    mapper.load("Shaders/map");
    pinchShader.load("Shaders/pinch-pull");
    
    fireBuffer1.allocate(ofGetWidth(), ofGetHeight());
    fireBuffer2.allocate(ofGetWidth(), ofGetHeight());
    fireTexture.allocate(ofGetWidth(), ofGetHeight());
    
    // Zero out the buffers
    fireBuffer1.begin();
    ofClear(0, 0, 0, 0);
    fireBuffer1.end();
    
    fireBuffer2.begin();
    ofClear(0, 0, 0, 0);
    fireBuffer2.end();
    
    fireTexture.begin();
    ofClear(0, 0, 0, 0);
    fireTexture.end();

    // Randomly generate the noise texture
    noise.allocate(ofGetWidth(), ofGetHeight(), OF_IMAGE_GRAYSCALE);
    
    unsigned char * pixels = noise.getPixels();
    int width = noise.getWidth();
    int height = noise.getHeight();
    for(int y=0; y<height; y++) {
        for(int x=0; x<width; x++) {
            int i = y * width + x;
            pixels[i] = 255 * ofNoise(x, y);
        }
    }
    noise.update();

}

float calcDistance(float x1, float y1, float x2, float y2){
    return sqrt( powf( (x2 - x1), 2 ) + powf( (y2 - y1), 2 ) );
}

//--------------------------------------------------------------
void ofApp::update(){
    // Calculate the pinch/pull force and midpoint if we need to
    if (moved) {
        midPoint.set(((cX1Current + cX2Current) / 2), ((cY1Current + cY2Current) / 2));
        float initDist = calcDistance(cX1Start, cY1Start, cX2Start, cY2Start);
        float curDist = calcDistance(cX1Current, cY1Current, cX2Current, cY2Current);
        pullForce = curDist - initDist;
    }
}

//--------------------------------------------------------------
void ofApp::draw(){
    
    /*generateFireTexture();
    
    burnShader.begin();
    burnShader.setUniformTexture("fireTex", fireTexture.getTextureReference(), 1);
    fireSpreadShader.setUniformTexture("noiseTex", noise.getTextureReference(), 2);
    baseImage.draw(0, 0);
    burnShader.end();*/
    
    baseImage.getTextureReference().bind();
    pinchShader.begin();
    pinchShader.setUniform1f("pullForce", pullForce);
    pinchShader.setUniform2f("midPoint", midPoint.x - ofGetWidth() / 2.0, midPoint.y - ofGetHeight() / 2.0);
    
    ofPushMatrix();
    ofTranslate(ofGetWidth()/2, ofGetHeight()/2);
    imagePlane.draw();
    ofPopMatrix();
    
    pinchShader.end();
    baseImage.getTextureReference().unbind();
    
}

//--------------------------------------------------------------
void ofApp::exit(){

}

//--------------------------------------------------------------
void ofApp::touchDown(ofTouchEventArgs & touch){
    if (touch.numTouches == 1) {
        singletouch = true;
        cX = touch.x;
        cY = touch.y;
    } else if (touch.numTouches == 2) {
        if (!twoTouch) {
            twoTouch = true;
            cX1Start = touch.x;
            cY1Start = touch.y;
        } else {
            twoTouch = false;
            cX2Start = touch.x;
            cY2Start = touch.y;
        }
    }
}

//--------------------------------------------------------------
void ofApp::touchMoved(ofTouchEventArgs & touch){
    if (touch.numTouches == 1) {
        singletouch = true;
        cX = touch.x;
        cY = touch.y;
    } else if (touch.numTouches == 2) {
        if (!twoTouch) {
            twoTouch = true;
            cX1Current = touch.x;
            cY1Current = touch.y;
        } else {
            twoTouch = false;
            cX2Current = touch.x;
            cY2Current = touch.y;
        }
        moved = true;
    }
}

//--------------------------------------------------------------
void ofApp::touchUp(ofTouchEventArgs & touch){
    singletouch = false;
    twoTouch = false;
    moved = false;
}

//--------------------------------------------------------------
void ofApp::touchDoubleTap(ofTouchEventArgs & touch){
}

//--------------------------------------------------------------
void ofApp::touchCancelled(ofTouchEventArgs & touch){
    singletouch = false;
    twoTouch = false;
    moved = false;
}

//--------------------------------------------------------------
void ofApp::lostFocus(){

}

//--------------------------------------------------------------
void ofApp::gotFocus(){

}

//--------------------------------------------------------------
void ofApp::gotMemoryWarning(){

}

//--------------------------------------------------------------
void ofApp::deviceOrientationChanged(int newOrientation){

}

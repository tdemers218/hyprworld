import QtQuick
import qs.Commons
Canvas {
    id:root
    property string kind:"minimap"
    property color ink:Color.foreground
    width:20;height:20
    onKindChanged:requestPaint()
    onInkChanged:requestPaint()
    onPaint:{
        var c=getContext('2d');c.reset();c.strokeStyle=ink;c.fillStyle=ink;c.lineWidth=1.5;c.lineCap='round';c.lineJoin='round';
        function line(x,y,a,b){c.beginPath();c.moveTo(x,y);c.lineTo(a,b);c.stroke()}
        function box(x,y,w,h){c.strokeRect(x,y,w,h)}
        if(kind==='minimap'){box(4,5,5,4);box(11,5,5,4);box(4,11,5,4)}
        else if(kind==='overview'){line(2,7,2,2);line(2,2,7,2);line(13,2,18,2);line(18,2,18,7);line(2,13,2,18);line(2,18,7,18);line(13,18,18,18);line(18,18,18,13)}
        else if(kind==='workflow'){c.beginPath();c.moveTo(2,6);c.bezierCurveTo(14,-2,6,22,18,14);c.stroke()}
        else if(kind==='placement'){box(1,8,4,4);box(14,1,4,4);box(14,14,4,4);line(5,10,10,10);line(10,10,10,3);line(10,3,14,3);line(10,10,10,16);line(10,16,14,16)}
        else if(kind==='groups'){box(2,2,16,16);line(10,2,10,18);line(10,10,18,10)}
        else if(kind==='startup'){c.beginPath();c.arc(10,11,7,-Math.PI/3,Math.PI*4/3);c.stroke();line(10,1,10,10)}
        else if(kind==='shortcuts'){box(1,4,18,12);for(var y=7;y<13;y+=3)for(var x=4;x<17;x+=3)c.fillRect(x,y,1,1);line(7,14,13,14)}
        else {c.beginPath();c.arc(10,10,5,0,Math.PI*2);c.stroke();for(var i=0;i<8;i++){var a=i*Math.PI/4;line(10+6*Math.cos(a),10+6*Math.sin(a),10+8*Math.cos(a),10+8*Math.sin(a))}c.beginPath();c.arc(10,10,1.5,0,Math.PI*2);c.stroke()}
    }
}

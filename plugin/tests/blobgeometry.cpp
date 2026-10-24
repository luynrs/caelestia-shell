#include "blobgroup.hpp"
#include "blobinvertedrect.hpp"

#include <qguiapplication.h>
#include <qsggeometry.h>
#include <qsgnode.h>

#include <cstdio>
#include <cstdlib>

class c_inverted_rect_probe : public caelestia::blobs::BlobInvertedRect {
public:
    using BlobInvertedRect::updatePaintNode;
    using BlobInvertedRect::updatePolish;
};

int main(int argc, char** argv) {
    const QGuiApplication application(argc, argv);
    caelestia::blobs::BlobGroup group;
    group.setSmoothing(4);
    c_inverted_rect_probe shape;
    shape.setGroup(&group);
    shape.setHeight(256);
    shape.setBorderLeft(10);
    shape.setBorderRight(10);
    shape.setBorderTop(10);
    shape.setBorderBottom(10);
    QSGNode* node{};
    bool valid = true;
    for (int i = 0; i < 10; i++) {
        shape.setWidth(i % 2 == 0 ? 256 : 10);
        shape.updatePolish();
        node = shape.updatePaintNode(node, nullptr);
        const auto* geometry = static_cast<QSGGeometryNode*>(node)->geometry();
        if (i % 2 == 0) {
            valid = valid && geometry->vertexCount() == 8 && geometry->indexCount() == 24 && geometry->drawingMode() == QSGGeometry::DrawTriangles;
        }
        else {
            valid = valid && geometry->vertexCount() == 4 && geometry->indexCount() == 0 && geometry->drawingMode() == QSGGeometry::DrawTriangleStrip;
        }
    }
    delete node;
    if (!valid) {
        fprintf(stderr, "Border geometry must rebuild when switching between frame and full quad\n");
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}

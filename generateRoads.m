function [xRoads,yRoads,roadVertices] = generateRoads(mapSizeX,mapSizeY, blockSize)

    % find the center of the map
    mapCenter = ((mapSizeX/2) + (mapSizeY/2))/2;

    % initialize list of block centers 
    blockCenters = [];

    % place first block for the city pattern
    blockCenters = [mapCenter, mapCenter];

    % determine block center locations in x and y directions
    straightOffsets = [
        0, 1*blockSize; %1 north
        0, 2*blockSize; %2 north
        0, -1*blockSize; %1 south
        0, -2*blockSize; %2 south
        -1*blockSize, 0; %1 west
        -2*blockSize, 0; %2 west
        1*blockSize, 0; %1 east
        2*blockSize, 0; %2 east
    ];

    % fill in empty corner spaces of road grdi
    diagonalOffsets = [
        1*blockSize, 1*blockSize; %NE
        -1*blockSize, 1*blockSize; %NW
        -1*blockSize, -1*blockSize; %SW
        1*blockSize, -1*blockSize; %SE
    ];

    % add straight squares
    for i = 1:size(straightOffsets,1)
        newX = mapCenter + straightOffsets(i,1);
        newY = mapCenter + straightOffsets(i,2);
        blockCenters = [blockCenters; newX, newY];
    end

    % add diagonal squares
    for i = 1:size(diagonalOffsets,1)
        newX = mapCenter + diagonalOffsets(i,1);
        newY = mapCenter + diagonalOffsets(i,2);
        blockCenters = [blockCenters; newX, newY];
    end

    %initialize variables to store grid data
    xRoads = [];
    yRoads = [];
    cornerX = [];
    cornerY = [];
    %generate city grid using block center data
    for i = 1:size(blockCenters,1)
        cx = blockCenters(i,1); % center x
        cy = blockCenters(i,2); % center y

        %define corners of each square
        % Need to repeat 1st corner point to correctly draw square
        cornerX(:,i) = [cx - blockSize/2, cx + blockSize/2, cx + blockSize/2, cx - blockSize/2, cx - blockSize/2];
        cornerY(:,i) = [cy - blockSize/2, cy - blockSize/2, cy + blockSize/2, cy + blockSize/2, cy - blockSize/2];

        % Store corners (need to repeat 5th point to correctly draw square)
        xRoads = [xRoads, cornerX(1:5,i)];
        yRoads = [yRoads, cornerY(1:5,i)];
    end

    % Remove duplicate corner points
    roadVertices = [reshape(cornerX(1:4,:),1,[])' reshape(cornerY(1:4,:),1,[])'];
    roadVertices = unique(roadVertices,'rows');

end

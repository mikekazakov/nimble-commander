#pragma once

enum class FileDeletionOperationType // do not change ordering, there's a raw value persistancy in code
{
    MoveToTrash = 0,
    Delete      = 1
};

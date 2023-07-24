import { Asset } from "expo-media-library";
import { Dispatch, SetStateAction } from "react";

export interface MusicListPropsModel {
    list: Asset[],
    updateItem: Dispatch<SetStateAction<string | undefined>>
}
import * as MediaLibrary from 'expo-media-library';
import { FlatList } from 'react-native';

export default function MusicList() {
    const [musicFileList, setMusicFileList] = useState([]);

    const getAllMusicFilesToState = async () => {
        await MediaLibrary.requestPermissionsAsync();
        const assetsList = await MediaLibrary.getAssetsAsync({
            mediaType: MediaLibrary.MediaType.audio,
        });

        setMusicFileList(assetsList.assets);
    };

    return(
        <>
            {getAllMusicFilesToState()}
            <FlatList data={musicFileList} renderItem={({item}) => <div>{item.filename}</div>} />
        </>
    );
}
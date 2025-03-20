import { Asset } from 'expo-media-library';
import { useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, StyleSheet, View, Button } from 'react-native';
import { MusicListPropsModel } from 'src/shared/models/MusicListPropsModel';

export default function MusicList({ list, updateItem }: MusicListPropsModel) {
    const [displayLoader, setDisplayLoader] = useState<boolean>(true);

    useEffect(() => {
        if(list.length === 0) {
            setDisplayLoader(false);
        }
    }, [list]);

    return(
        <View style={componentStyles.listBox}>
            {displayLoader === true ? <ActivityIndicator size={"large"} /> :
            <FlatList data={list} renderItem={({ item }) => <Button title={item.filename} onPress={() => updateItem(item.filename)}></Button>} keyExtractor={(item: Asset) => item.filename} />}
        </View>
    );
}

const componentStyles = StyleSheet.create({
    listBox: {
        width: 300,
        height: "95%",
        border: "1 solid black",
        borderRadius: 50,
        backgroundColor: "grey",
        padding: 30
    }
});
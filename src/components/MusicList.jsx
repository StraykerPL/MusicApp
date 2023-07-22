import { useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, StyleSheet, View, Button } from 'react-native';

export default function MusicList(props) {
    const [displayLoader, setDisplayLoader] = useState(true);

    useEffect(() => {
        if(props.list !== []) {
            setDisplayLoader(false);
        }
    }, [props.list]);

    return(
        <View style={componentStyles.listBox}>
            {displayLoader === true ? <ActivityIndicator size={"large"} /> :
            <FlatList data={props.list} renderItem={({item}) => <Button title={item.filename} onPress={() => {}}></Button>} />}
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
import { useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, Text, View } from 'react-native';

export default function MusicList(props) {
    const [displayLoader, setDisplayLoader] = useState(true);

    useEffect(() => {
        if(props.list !== []) {
            setDisplayLoader(false);
        }
    }, [props.list]);

    return(
        <View>
            {displayLoader === true ? <ActivityIndicator size={"large"} /> :
            <FlatList data={props.list} renderItem={({item}) => <Text>{item.filename}</Text>} />}
        </View>
    );
}
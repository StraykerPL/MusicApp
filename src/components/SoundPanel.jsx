import { useEffect, useState } from "react";
import { StyleSheet, Text, View } from "react-native";
import { Audio } from 'expo-av';
import AntDesign from '@expo/vector-icons/AntDesign';

export default function SoundPanel(props) {
    const [soundBuffor, setSoundBuffor] = useState();

    const loadMusicAsset = async () => {
        await soundBuffor.loadAsync(props.musicAsset);
    };

    const play = async () => {
        const status = await soundBuffor.getStatusAsync();
        if(!status.isLoaded) {
            await loadMusicAsset();
        }

        await soundBuffor.playAsync();
    };

    const stop = async () => {
        await soundBuffor.pauseAsync();
    };

    useEffect(() => {
        setSoundBuffor(new Audio.Sound());
        return () => {async () => { await soundBuffor.unloadAsync(); }}
    }, []);

    useEffect(() => {    
        async () => {
            const status = await soundBuffor.getStatusAsync();
            if (status.isLoaded) {
                await soundBuffor.unloadAsync();
            }

            await loadMusicAsset();
        };
    }, [props.musicAsset]);

    // useEffect(() => {
    //     console.log("---- SoundPanel ----");
    //     console.log("soundBuffor: " + soundBuffor);
    //     console.log("musicAsset: " + props.musicAsset);
    // });

    return(
        <View style={componentStyles.soundPanel}>
            <View style={componentStyles.soundPanel.metaData}>
                <Text>{props.musicAsset?.filename}</Text>
                {/* <Text>{props.musicAsset.musicAuthor}</Text> */}
            </View>
            <View style={componentStyles.soundPanel.controlButtons}>
                <AntDesign.Button name="caretright" size={16} color="white" onPress={play} />
                <AntDesign.Button name="pause" size={16} color="white" onPress={stop} />
            </View>
        </View>
    );
}

const componentStyles = StyleSheet.create({
    soundPanel: {
        width: 300,
        height: 75,
        display: "flex",
        flexDirection: "row",
        justifyContent: "space-between",
        alignItems: "center",
        paddingRight: 20,
        paddingLeft: 20,
        backgroundColor: "lightblue",
        shadowColor: "#000",
        shadowOffset: {
            width: 0,
            height: 12,
        },
        shadowOpacity: 0.58,
        shadowRadius: 16.00,
        elevation: 24,
        metaData: {
            display: "flex",
            flexDirection: "column",
            maxWidth: 150
        },
        controlButtons: {
            display: "flex",
            flexDirection: "row"
        }
    }
});